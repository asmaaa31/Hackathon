
var act    = btn_click;      // set by the Draw event when a button was clicked
btn_click  = "";
var typing = (quiz && phase == "predict");     // the player is typing their answer

var k_next  = (!typing && keyboard_check_pressed(ord("N")))     || (act == "next");
var k_back  = (!typing && keyboard_check_pressed(vk_backspace)) || (act == "back");
var k_auto  = (!typing && keyboard_check_pressed(ord("A")))     || (act == "auto");
var k_pause = (!typing && keyboard_check_pressed(vk_space));
var k_round = keyboard_check_pressed(vk_enter) || (act == "round");
var k_mode  = keyboard_check_pressed(vk_tab)   || (act == "mode");

if (k_mode) {
    quiz = !quiz;
    if (quiz) {
        new_round();
    } else {
        reset_search();
        phase = "sandbox";
    }
}


if (quiz) {
    if (phase == "predict") {
        // keep the typed text short
        if (string_length(keyboard_string) > 5) {
            keyboard_string = string_copy(keyboard_string, 1, 5);
        }

        if (keyboard_check_pressed(vk_enter)) {
            var answer = string_lower(string_replace_all(keyboard_string, " ", ""));

            if (answer == "bfs" || answer == "dfs") {
                guess           = answer;
                keyboard_string = "";
                input_msg       = "";
                start_search("bfs");     // always show BFS first, then DFS
                phase = "run_bfs";
            } else {
                input_msg = "Please type bfs or dfs, then press ENTER";
            }
        }
    }
    else if (phase == "run_bfs" && mode == "done") {
        phase_timer++;
        // step-by-step: wait for N / the button.  autoplay: wait one second.
        var go = manual ? k_next : (phase_timer >= 60);
        if (go) {
            phase_timer = 0;
            start_search("dfs");
            phase = "run_dfs";
        }
    }
    else if (phase == "run_dfs" && mode == "done") {
        var b = (bfs_len == -2) ? 99999 : bfs_visited;
        var d = (dfs_len == -2) ? 99999 : dfs_visited;
        winner  = (b < d) ? "bfs" : ((d < b) ? "dfs" : "tie");
        correct = (winner == "tie" || guess == winner);

        rounds++;
        if (correct) {
            score++;
            streak++;
        } else {
            streak = 0;
        }
        phase = "result";
    }
    else if (phase == "result") {
        if (k_round) new_round();
    }
}


if (!quiz) {
    var mcx = (mouse_x - ox) div cell;
    var mcy = mouse_y div cell;
    var inside = (mouse_x >= ox && mouse_y >= 0 && mcx < cols && mcy < rows);

    if (inside && mode != "running") {
        var ci = mcy * cols + mcx;
        var special = (ci == start_cell || ci == goal_cell);

        if (!special) {
            if (mouse_check_button(mb_left) && !wall[ci]) {
                wall[ci] = true;
                reset_search();
            }
            if (mouse_check_button(mb_right) && wall[ci]) {
                wall[ci] = false;
                reset_search();
            }
        }
        if (keyboard_check_pressed(ord("S")) && !wall[ci] && ci != goal_cell) {
            start_cell = ci;
            reset_search();
        }
        if (keyboard_check_pressed(ord("G")) && !wall[ci] && ci != start_cell) {
            goal_cell = ci;
            reset_search();
        }
    }

    if (keyboard_check_pressed(ord("B")) || act == "bfs")   start_search("bfs");
    if (keyboard_check_pressed(ord("D")) || act == "dfs")   start_search("dfs");
    if (keyboard_check_pressed(ord("R")) || act == "reset") reset_search();

    if (keyboard_check_pressed(ord("C")) || act == "clear") {
        for (var n = 0; n < total; n++) wall[n] = false;
        reset_search();
    }
    if (keyboard_check_pressed(ord("M")) || act == "random") {
        for (var n = 0; n < total; n++) {
            wall[n] = (n != start_cell && n != goal_cell && random(1) < 0.25);
        }
        reset_search();
    }
}


if (k_pause) paused = !paused;
if (k_auto)  manual = !manual;

// go back one step (not allowed on the result screen)
if (k_back && (mode == "running" || mode == "done") && !(quiz && phase == "result")) {
    go_back();
}

if (keyboard_check_pressed(vk_up))   spd = min(spd + 1, 7);
if (keyboard_check_pressed(vk_down)) spd = max(spd - 1, 0);

if (mode == "running") {
    if (manual) {
        // step-by-step: nothing happens until the player presses N or the button
        if (k_next) search_step();
    } else if (!paused) {
        timer++;
        if (timer >= speed_delay[spd]) {
            timer = 0;
            repeat (speed_steps[spd]) {
                if (mode == "running") search_step();
            }
        }
    } else if (k_next) {
        search_step();
    }
}
