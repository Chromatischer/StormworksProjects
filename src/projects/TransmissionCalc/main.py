import sys
import solver

# ANSI Colors
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_RED = "\033[91m"
C_GREEN = "\033[92m"
C_YELLOW = "\033[93m"
C_BLUE = "\033[94m"
C_MAGENTA = "\033[95m"
C_CYAN = "\033[96m"
C_WHITE = "\033[97m"
C_GREY = "\033[90m"


def clear_screen():
    print("\033[H\033[J", end="")


def print_header():
    print(f"{C_BLUE}{'=' * 60}{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}      STORMWORKS TRANSMISSION CALCULATOR      {C_RESET}")
    print(f"{C_BLUE}{'=' * 60}{C_RESET}")


def get_float_input(prompt):
    while True:
        try:
            val = float(input(f"{C_GREEN}{prompt}{C_RESET}"))
            if val <= 0:
                print(f"{C_RED}Please enter a positive number.{C_RESET}")
                continue
            return val
        except ValueError:
            print(f"{C_RED}Invalid input. Please enter a number.{C_RESET}")


def get_int_input(prompt):
    while True:
        try:
            val = int(input(f"{C_GREEN}{prompt}{C_RESET}"))
            if val <= 0:
                print(f"{C_RED}Please enter a positive integer.{C_RESET}")
                continue
            return val
        except ValueError:
            print(f"{C_RED}Invalid input. Please enter an integer.{C_RESET}")


def format_gearbox_line(idx, gb):
    direction = "TOWARD (Multiply)" if gb.orientation == 1 else "AWAY (Divide)"
    color = C_CYAN if gb.orientation == 1 else C_YELLOW
    return f"  {C_BOLD}Gearbox {idx}:{C_RESET} {color}{direction}{C_RESET} -> OFF:{C_MAGENTA}{gb.ratio_a_name}{C_RESET} | ON:{C_MAGENTA}{gb.ratio_b_name}{C_RESET}"


def get_result_stats(result):
    """Helper to get formatted stats for a result."""
    main_ratios = solver.filter_main_sequence(result["ratios"])
    r_min = main_ratios[0] if main_ratios else 0
    r_max = main_ratios[-1] if main_ratios else 0
    count = len(main_ratios)

    avg_step = 0.0
    if count > 1:
        steps = [main_ratios[i + 1] / main_ratios[i] for i in range(count - 1)]
        avg_step = sum(steps) / len(steps)

    return r_min, r_max, avg_step, count


def show_comparison(all_results, target_min, target_max):
    """
    Displays top 2 results from each strategy for comparison.
    Returns: (mode, data) where mode is 'result' or 'strategy_list'
             If 'result': data is (strategy_name, result)
             If 'strategy_list': data is strategy_name
    """
    clear_screen()
    print_header()
    print(f"{C_BOLD}{C_GREEN}Strategy Comparison (Top 2 per Strategy){C_RESET}")
    print(f"{C_GREY}Goal: {target_min} - {target_max}{C_RESET}")
    print(f"{C_BLUE}{'=' * 60}{C_RESET}")

    # Store selections: mapping letter -> (strategy, result)
    selections = {}
    # Store strategy mappings: number -> strategy_name
    strategy_mappings = {}
    strategy_num = 1

    letter_idx = ord("a")

    for strategy in solver.STRATEGIES.keys():
        results = all_results[strategy]
        if not results:
            continue

        # Map number to strategy
        strategy_mappings[str(strategy_num)] = strategy
        strategy_num += 1

        print(f"\n{C_BOLD}{C_MAGENTA}[{
              (strategy_num - 1)}] {strategy}{C_RESET}:")
        for i, res in enumerate(results[:2]):
            r_min, r_max, avg_step, count = get_result_stats(res)
            range_str = f"{r_min:.2f} - {r_max:.2f}"

            # Assign letter
            let = chr(letter_idx)
            selections[let] = (strategy, res)
            letter_idx += 1

            print(
                f"  [{C_CYAN}{let}{C_RESET}] Range: {C_YELLOW}{range_str}{
                    C_RESET
                } | Step: {C_GREEN}{avg_step:.2f}x{C_RESET} | Gears: {C_WHITE}{count}{
                    C_RESET
                }"
            )

    print(f"\n{C_BLUE}{'-' * 60}{C_RESET}")

    # Build help text
    if selections:
        letter_range = f"{list(selections.keys())[
            0]}-{list(selections.keys())[-1]}"
    else:
        letter_range = ""

    if strategy_mappings:
        num_range = f"{min(strategy_mappings.keys())
                       }-{max(strategy_mappings.keys())}"
        num_help = f"| Press {C_CYAN}{num_range}{C_RESET} for strategy list"
    else:
        num_help = ""

    choice = (
        input(
            f"{C_GREEN}Select: [{C_CYAN}{letter_range}{C_RESET}] for details {
                num_help
            } | [{C_CYAN}r{C_RESET}] restart: {C_RESET}"
        )
        .strip()
        .lower()
    )

    if choice == "r":
        return None, None
    elif choice in selections:
        return "result", selections[choice]
    elif choice in strategy_mappings:
        return "strategy_list", strategy_mappings[choice]
    else:
        return None, None


def show_details(result, strategy_name=""):
    print(
        f"\n{C_BOLD}{
            C_WHITE}--- CONFIGURATION DETAILS ({strategy_name}) ---{C_RESET}"
    )
    print(f"Score: {C_GREEN}{result['score']:.2f}{C_RESET}")

    setup = result["setup"]
    print(f"\n{C_BOLD}Setup Instructions:{C_RESET}")
    for i, gb in enumerate(setup, 1):
        print(format_gearbox_line(i, gb))

    # Recalculate detailed info including switch states
    all_details = solver.calculate_detailed_ratios(setup)

    # Sort by ratio
    all_details.sort(key=lambda x: x["ratio"])

    # Filter "Main Sequence" vs "Left Out"
    # Logic: A gear is 'Main' if it is significantly distinct from the previous Main gear.
    # Threshold: 2% difference

    main_sequence = []
    left_out = []

    last_main_ratio = -1.0

    for item in all_details:
        r = item["ratio"]
        # If it's the first gear, or significantly larger than the last accepted gear
        if last_main_ratio < 0 or r > last_main_ratio * 1.02:
            main_sequence.append(item)
            last_main_ratio = r
        else:
            left_out.append(item)

    # Helper to format states
    def fmt_states(states):
        # states is list of 0/1. Convert to ON/OFF strings
        parts = []
        for s in states:
            if s:
                parts.append(f"{C_GREEN}ON{C_RESET}")
            else:
                parts.append(f"{C_RED}OFF{C_RESET}")
        return ", ".join(parts)

    print(f"\n{C_BOLD}{C_GREEN}[ Main Gear Sequence ]{C_RESET}")
    print(
        f"{C_GREY}{'Gear':<6} | {'Ratio':<8} | {'Graph':<40} | {
            'Switch States (GB1, GB2...)'
        }{C_RESET}"
    )
    print(f"{C_GREY}{'-' * 100}{C_RESET}")

    # Calculate max ratio for graph scaling
    max_r = main_sequence[-1]["ratio"] if main_sequence else 1.0
    max_w = 40

    for i, item in enumerate(main_sequence, 1):
        r = item["ratio"]

        # Calculate Step Size
        step_str = ""
        if i > 1:
            prev = main_sequence[i - 2]["ratio"]
            if prev > 0:
                mult = r / prev
                step_str = f" {mult:.2f}x"

        # Graph Logic
        # Ensure total width fits within max_w
        step_len = len(step_str)
        max_bar_width = max_w - step_len

        desired_bar_len = int((r / max_r) * max_w)

        # Clamp bar length to ensure step text fits
        actual_bar_len = min(desired_bar_len, max_bar_width)
        if actual_bar_len == 0 and r > 0 and max_bar_width > 0:
            actual_bar_len = 1

        bar_chars = "█" * actual_bar_len
        padding = " " * (max_w - (actual_bar_len + step_len))

        # Compose Graph Column: Blue Bar + Cyan Text + Padding
        graph_col = f"{C_BLUE}{bar_chars}{C_RESET}{
            C_CYAN}{step_str}{C_RESET}{padding}"

        print(
            f"{C_BOLD}{i:<6}{C_RESET} | {C_YELLOW}{item['ratio']:<8.3f}{C_RESET} | {
                graph_col
            } | {fmt_states(item['states'])}"
        )

    if left_out:
        print(f"\n{C_BOLD}{C_GREY}[ Unused / Redundant Ratios ]{C_RESET}")
        print(f"{C_GREY}{'Ratio':<8} | {'Switch States'}{C_RESET}")
        print(f"{C_GREY}{'-' * 40}{C_RESET}")
        for item in left_out:
            print(
                f"{C_GREY}{item['ratio']:<8.3f} | {
                    fmt_states(item['states'])}{C_RESET}"
            )
    else:
        print(f"\n{C_GREY}(No redundant ratios found){C_RESET}")

    # Stats based on Main Sequence
    if len(main_sequence) > 1:
        steps = [
            main_sequence[i + 1]["ratio"] / main_sequence[i]["ratio"]
            for i in range(len(main_sequence) - 1)
        ]
        avg_step = sum(steps) / len(steps)
        print(f"\nAverage Step Multiplier (Main Seq): {
              C_CYAN}{avg_step:.3f}x{C_RESET}")

    # Export String Generation
    # Code mapping: 0-9, A-Z, a-z, +, / (64 chars)
    # Allows encoding states for up to 6 gearboxes (6 bits = 64 values)
    CODE_MAP = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"

    export_str = ""
    for item in main_sequence:
        # Calculate state value: Bit 0 = GB1, Bit 1 = GB2...
        val = 0
        for i, s in enumerate(item["states"]):
            if s:
                val += 1 << i

        if val < len(CODE_MAP):
            export_str += CODE_MAP[val]
        else:
            export_str += "?"  # Should not happen if count <= 6

    print(f"\nExport String: {C_BOLD}{C_MAGENTA}{export_str}{C_RESET}")

    input(f"\n{C_GREEN}Press Enter to return to list...{C_RESET}")


def main():
    while True:
        clear_screen()
        print_header()

        try:
            target_min = get_float_input("Target Min Ratio (e.g. 0.5): ")
            target_max = get_float_input("Target Max Ratio (e.g. 3.0): ")
            count = get_int_input("Number of Gearboxes (max 4 recommended): ")

            if count > 5:
                print(
                    f"\n{
                        C_YELLOW
                    }Warning: >5 gearboxes may take a long time to calculate.{C_RESET}"
                )
                confirm = input(f"{C_GREEN}Continue? (y/n): {C_RESET}")
                if confirm.lower() != "y":
                    continue

            # Calculate for ALL strategies
            print(
                f"\n{C_CYAN}Calculating configurations for all strategies...{C_RESET}"
            )
            all_results = {}
            for strat in solver.STRATEGIES.keys():
                results = solver.find_best_configurations(
                    count, target_min, target_max, strategy=strat
                )
                all_results[strat] = results

            # Show Comparison
            mode, selection = show_comparison(
                all_results, target_min, target_max)

            if mode is None:
                continue  # User restarted

            if mode == "strategy_list":
                # Direct navigation to list view via number key
                strategy_name = selection  # type: ignore
                selected_results = all_results[strategy_name]

                while True:
                    clear_screen()
                    print_header()
                    print(
                        f"Strategy: {C_MAGENTA}{strategy_name}{C_RESET} | Goal: {
                            C_YELLOW
                        }{target_min} - {target_max}{C_RESET} | Gearboxes: {C_YELLOW}{
                            count
                        }{C_RESET}"
                    )
                    print(f"{C_BLUE}{'-' * 70}{C_RESET}")
                    print(
                        f"{C_BOLD}{'ID':<4} | {'Score':<8} | {'Range':<20} | {
                            'Gear Count':<10}{C_RESET}"
                    )
                    print(f"{C_BLUE}{'-' * 70}{C_RESET}")

                    for i, res in enumerate(selected_results, 1):
                        r_min, r_max, avg_step, count_g = get_result_stats(res)
                        range_str = f"{r_min:.2f} - {r_max:.2f}"
                        print(
                            f"{C_CYAN}{i:<4}{C_RESET} | {res['score']:<8.2f} | {
                                range_str:<20} | {count_g:<10}"
                        )

                    print(f"{C_BLUE}{'-' * 70}{C_RESET}")
                    list_choice = (
                        input(
                            f"\n{C_GREEN}Enter ID to view details, 'b' for back: {
                                C_RESET
                            }"
                        )
                        .strip()
                        .lower()
                    )

                    if list_choice == "b":
                        break
                    else:
                        try:
                            idx = int(list_choice)
                            if 1 <= idx <= len(selected_results):
                                result = selected_results[idx - 1]
                                clear_screen()
                                # type: ignore
                                show_details(result, strategy_name)
                                input(f"{C_GREEN}Press Enter...{C_RESET}")
                            else:
                                print(f"{C_RED}Invalid ID.{C_RESET}")
                                input(f"{C_GREEN}Press Enter...{C_RESET}")
                        except ValueError:
                            print(f"{C_RED}Invalid input.{C_RESET}")
                            input(f"{C_GREEN}Press Enter...{C_RESET}")
            elif mode == "result":
                # Original flow: select specific result first
                strategy_name, result = selection  # type: ignore
                selected_results = all_results[strategy_name]

                while True:
                    clear_screen()
                    show_details(result, strategy_name)

                    sub_choice = (
                        input(
                            f"\n{C_GREEN}[V]iew List for {
                                strategy_name
                            } or [B]ack to comparison: {C_RESET}"
                        )
                        .strip()
                        .lower()
                    )

                    if sub_choice == "b":
                        break
                    elif sub_choice == "v":
                        while True:
                            clear_screen()
                            print_header()
                            print(
                                f"Strategy: {C_MAGENTA}{strategy_name}{
                                    C_RESET
                                } | Goal: {C_YELLOW}{target_min} - {target_max}{
                                    C_RESET
                                } | Gearboxes: {C_YELLOW}{count}{C_RESET}"
                            )
                            print(f"{C_BLUE}{'-' * 70}{C_RESET}")
                            print(
                                f"{C_BOLD}{'ID':<4} | {'Score':<8} | {'Range':<20} | {
                                    'Gear Count':<10}{C_RESET}"
                            )
                            print(f"{C_BLUE}{'-' * 70}{C_RESET}")

                            for i, res in enumerate(selected_results, 1):
                                r_min, r_max, avg_step, count_g = get_result_stats(
                                    res)
                                range_str = f"{r_min:.2f} - {r_max:.2f}"
                                print(
                                    f"{C_CYAN}{i:<4}{C_RESET} | {res['score']:<8.2f} | {
                                        range_str:<20} | {count_g:<10}"
                                )

                            print(f"{C_BLUE}{'-' * 70}{C_RESET}")
                            list_choice = (
                                input(
                                    f"\n{
                                        C_GREEN
                                    }Enter ID to view details, 'b' for back: {C_RESET}"
                                )
                                .strip()
                                .lower()
                            )

                            if list_choice == "b":
                                break
                            else:
                                try:
                                    idx = int(list_choice)
                                    if 1 <= idx <= len(selected_results):
                                        result = selected_results[idx - 1]
                                        clear_screen()
                                        show_details(result, strategy_name)
                                        input(
                                            f"{C_GREEN}Press Enter...{C_RESET}")
                                    else:
                                        print(f"{C_RED}Invalid ID.{C_RESET}")
                                        input(
                                            f"{C_GREEN}Press Enter...{C_RESET}")
                                except ValueError:
                                    print(f"{C_RED}Invalid input.{C_RESET}")
                                    input(f"{C_GREEN}Press Enter...{C_RESET}")
        except KeyboardInterrupt:
            print(f"\n{C_CYAN}Goodbye!{C_RESET}")
            sys.exit(0)


if __name__ == "__main__":
    main()
