import itertools
import math

# Available Ratios in Stormworks
# Display Name -> Numerical Value
RATIO_MAP = {
    "1:1": 1.0,
    "6:5": 1.2,
    "3:2": 1.5,
    "9:5": 1.8,
    "2:1": 2.0,
    "5:2": 2.5,
    "3:1": 3.0,
}

# Invert map for display
VAL_TO_NAME = {v: k for k, v in RATIO_MAP.items()}


class GearboxConfig:
    def __init__(self, orientation, ratio_a_name, ratio_b_name):
        """
        orientation: 1 for Toward (multiply), -1 for Away (divide)
        ratio_a_name: string key from RATIO_MAP
        ratio_b_name: string key from RATIO_MAP
        """
        self.orientation = orientation
        self.ratio_a_name = ratio_a_name
        self.ratio_b_name = ratio_b_name
        self.val_a = RATIO_MAP[ratio_a_name]
        self.val_b = RATIO_MAP[ratio_b_name]

    def get_ratio_val(self, is_on):
        """Returns the ratio value for a specific state (False=Off/A, True=On/B)"""
        val = self.val_b if is_on else self.val_a
        if self.orientation == 1:
            return val
        else:
            return 1.0 / val

    def get_state_str(self, is_on):
        """Returns 'On' or 'Off' for display"""
        return "ON" if is_on else "OFF"

    def __repr__(self):
        direction = "TOWARD" if self.orientation == 1 else "AWAY"
        return f"{direction} (OFF:{self.ratio_a_name}, ON:{self.ratio_b_name})"


def generate_gearbox_options():
    """Generates all possible single gearbox configurations."""
    ratio_keys = list(RATIO_MAP.keys())
    options = []

    # Generate unique pairs of ratios.
    for r1, r2 in itertools.combinations(ratio_keys, 2):
        # Orientation Toward
        options.append(GearboxConfig(1, r1, r2))
        # Orientation Away
        options.append(GearboxConfig(-1, r1, r2))

    return options


def calculate_detailed_ratios(gearboxes):
    """
    Returns a list of dicts:
    {
        'ratio': float,
        'states': [0, 1, 0...] # 0=Off, 1=On for each gearbox
    }
    """
    # Create list of (state_idx, value) tuples for each gearbox
    gb_options = []
    for gb in gearboxes:
        gb_options.append([(0, gb.get_ratio_val(False)),
                          (1, gb.get_ratio_val(True))])

    results = []
    for combination in itertools.product(*gb_options):
        # combination is a tuple of (state_idx, val)
        current_states = [item[0] for item in combination]
        total_ratio = 1.0
        for item in combination:
            total_ratio *= item[1]

        results.append({"ratio": total_ratio, "states": current_states})

    return results


def calculate_transmission_ratios(gearboxes):
    """
    Legacy wrapper for scoring: returns sorted unique floats.
    """
    details = calculate_detailed_ratios(gearboxes)
    # Extract unique ratios
    unique = set(d["ratio"] for d in details)
    return sorted(list(unique))


def filter_main_sequence(ratios):
    """
    Returns the subset of ratios that form the 'useful' sequence.
    Excludes duplicates/near-duplicates.
    """
    if not ratios:
        return []

    main_seq = []
    last_r = -1.0
    for r in ratios:
        if last_r < 0 or r > last_r * 1.02:
            main_seq.append(r)
            last_r = r
    return main_seq


STRATEGIES = {
    "Balanced": {
        "range": 2.0,
        "smoothness": 1.0,
        "utilization": 1.0,
        "filter_max": False,
    },
    "Range First": {
        "range": 10.0,
        "smoothness": 0.1,
        "utilization": 0.5,
        "filter_max": False,
    },
    "Smoothness First": {
        "range": 2.0,
        "smoothness": 5.0,
        "utilization": 0.5,
        "filter_max": False,
    },
    "Max Gears": {
        "range": 2.0,
        "smoothness": 0.5,
        "utilization": 10.0,
        "filter_max": False,
    },
    "Quality Over Quantity": {
        "range": 10.0,
        "smoothness": 10.0,
        "utilization": 10.0,
        "filter_max": False,
    },
}


def score_configuration(gearboxes, target_min, target_max, strategy="Balanced"):
    """
    Scores a setup based on strategy weights.
    Lower score is better.
    """
    weights = STRATEGIES[strategy]

    ratios = calculate_transmission_ratios(gearboxes)
    if not ratios:
        return float("inf"), ratios

    # Calculate actual used sequence
    main_ratios = filter_main_sequence(ratios)

    actual_min = ratios[0]
    actual_max = ratios[-1]

    # Range Penalty:
    min_error = abs(actual_min - target_min) / target_min
    max_error = abs(actual_max - target_max) / target_max

    raw_range_score = (min_error * 100) + (max_error * 100)
    range_score = raw_range_score * weights["range"]

    # Smoothness & Utilization:
    if len(main_ratios) > 1:
        log_ratios = [math.log(r) for r in main_ratios]
        gaps = [log_ratios[i + 1] - log_ratios[i]
                for i in range(len(log_ratios) - 1)]

        avg_gap = sum(gaps) / len(gaps)
        variance = sum((g - avg_gap) ** 2 for g in gaps) / len(gaps)
        std_dev = math.sqrt(variance)

        raw_smoothness_score = std_dev * 1000

        max_possible_gears = 2 ** len(gearboxes)
        utilization = len(main_ratios) / max_possible_gears
        raw_util_penalty = (1.0 - utilization) * 500.0

        smoothness_score = (raw_smoothness_score + raw_util_penalty) * weights[
            "smoothness"
        ]
        utilization_score = raw_util_penalty * weights["utilization"]

    else:
        smoothness_score = 500.0 * weights["smoothness"]
        utilization_score = 500.0 * weights["utilization"]

    total_score = range_score + smoothness_score + utilization_score
    return total_score, ratios


def find_best_configurations(
    num_gearboxes, target_min, target_max, top_n=5, strategy="Balanced"
):
    """
    Main solver function.
    """
    possible_gearboxes = generate_gearbox_options()
    strategy_config = STRATEGIES[strategy]

    best_results = []

    iterator = itertools.combinations_with_replacement(
        possible_gearboxes, num_gearboxes
    )

    for gear_setup in iterator:
        score, resulting_ratios = score_configuration(
            gear_setup, target_min, target_max, strategy
        )

        # Filter: Max Gears Only?
        if strategy_config["filter_max"]:
            # Check if we have 2^N unique ratios
            if len(resulting_ratios) < (2**num_gearboxes):
                continue

        best_results.append(
            {"score": score, "setup": gear_setup, "ratios": resulting_ratios}
        )

    # Sort by score (ascending)
    best_results.sort(key=lambda x: x["score"])

    return best_results[:top_n]
