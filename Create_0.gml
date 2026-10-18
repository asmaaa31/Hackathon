randomize();   


cols  = 20;
rows  = 15;
total = cols * rows;


ui      = min(room_width / 760, room_height * 0.44 / 394);   // text and panel scale
panel_h = 394 * ui;                                          // height of the text panel
cell    = max(8, floor(min(room_width / cols, (room_height - panel_h) / rows)));
grid_w  = cols * cell;
grid_h  = rows * cell;
ox      = floor((room_width - grid_w) / 2);                  // centres the grid sideways

wall       = array_create(total, false);
visited    = array_create(total, false);
discovered = array_create(total, false);
came_from  = array_create(total, -1);
dist       = array_create(total, 0);   // BFS: which ring a cell is in. DFS: how deep the trail is.

start_cell = 7 * cols + 2;
goal_cell  = 7 * cols + 17;

// four directions: up, right, down, left
dir_x = [0, 1, 0, -1];
dir_y = [-1, 0, 1, 0];


frontier    = ds_list_create();   // the SAME list is used as a queue (BFS) or a stack (DFS)
algo        = "none";             // "bfs", "dfs" or "none"
mode        = "idle";             // "idle", "running" or "done"
visit_count = 0;
found       = false;
current     = -1;
route       = [];
narrate     = "";                 // the live explanation text
manual      = true;               // true = step-by-step, false = autoplay
undo_stack  = [];                 // saved snapshots, so BACKSPACE can go back a step
btn_click   = "";                 // set when an on-screen button is clicked
btn_x       = 0;
btn_y       = 0;


paused      = false;
timer       = 0;
spd         = 3;                                 // 0..7
speed_delay = [30, 20, 12, 8, 5, 3, 1, 1];       // frames between steps
speed_steps = [1, 1, 1, 1, 1, 1, 1, 4];          // steps per tick

bfs_visited = -1;  bfs_len = -1;
dfs_visited = -1;  dfs_len = -1;


quiz        = true;
phase       = "predict";   // predict, run_bfs, run_dfs, result (or sandbox)
guess       = "";
winner      = "";
correct     = false;
phase_timer = 0;
score       = 0;
rounds      = 0;
streak      = 0;
input_msg   = "";
result_why  = "";          // the "why it was faster" explanation shown on the result screen


reset_search = function() {
    ds_list_clear(frontier);
    for (var n = 0; n < total; n++) {
        visited[n]    = false;
        discovered[n] = false;
        came_from[n]  = -1;
        dist[n]       = 0;
    }
    route       = [];
    visit_count = 0;
    found       = false;
    current     = -1;
    timer       = 0;
    mode        = "idle";
    algo        = "none";
    undo_stack  = [];
}

start_search = function(which) {
    reset_search();
    algo = which;
    discovered[start_cell] = true;
    ds_list_add(frontier, start_cell);
    mode = "running";

    if (which == "bfs") {
        narrate = "BFS (breadth-first search) explores in RINGS: every cell 1 step from S, then every cell 2 steps away, then 3... To do that it uses a QUEUE (first in, first out): it takes the OLDEST cell from the FRONT and adds new cells to the BACK.\n"
                + "Because closer cells are always taken before farther ones, the first time BFS reaches G it has found the shortest path.\n"
                + "Press NEXT STEP (or N) to take the first cell.";
    } else {
        narrate = "DFS (depth-first search) explores by DIVING: pick a direction and keep going as deep as possible, backing up only at a dead end. To do that it uses a STACK (last in, first out): it takes the NEWEST cell from the END.\n"
                + "It checks left, down, right, up, so 'up' ends on top and is tried first (then right, down, left).\n"
                + "Press NEXT STEP (or N) to take the first cell.";
    }
}
save_state = function() {
    var s = {};
    s.visited    = array_create(total, false);
    s.discovered = array_create(total, false);
    s.came_from  = array_create(total, -1);
    s.dist       = array_create(total, 0);
    array_copy(s.visited,    0, visited,    0, total);
    array_copy(s.discovered, 0, discovered, 0, total);
    array_copy(s.came_from,  0, came_from,  0, total);
    array_copy(s.dist,       0, dist,       0, total);

    s.frontier = [];
    for (var k = 0; k < ds_list_size(frontier); k++) {
        s.frontier[k] = frontier[| k];
    }
    s.visit_count = visit_count;
    s.current     = current;
    s.narrate     = narrate;

    undo_stack[array_length(undo_stack)] = s;
}

go_back = function() {
    var n = array_length(undo_stack);
    if (n == 0) {
        narrate = "Already at the very first step - nothing to go back to.";
        return;
    }

    var was_done = (mode == "done");
    var s = undo_stack[n - 1];
    array_resize(undo_stack, n - 1);

    array_copy(visited,    0, s.visited,    0, total);
    array_copy(discovered, 0, s.discovered, 0, total);
    array_copy(came_from,  0, s.came_from,  0, total);
    array_copy(dist,       0, s.dist,       0, total);

    ds_list_clear(frontier);
    for (var k = 0; k < array_length(s.frontier); k++) {
        ds_list_add(frontier, s.frontier[k]);
    }

    visit_count = s.visit_count;
    current     = s.current;
    narrate     = s.narrate;

    // if the search had already finished, un-finish it
    if (was_done) {
        if (algo == "bfs") { bfs_visited = -1; bfs_len = -1; }
        else               { dfs_visited = -1; dfs_len = -1; }
    }
    found       = false;
    route       = [];
    mode        = "running";
    phase_timer = 0;
    manual      = true;   // going back means the player wants to step through
}

search_step = function() {
    save_state();   // remember how things were, so BACKSPACE can return here

    if (ds_list_size(frontier) == 0) {
        finish_search(false);
        return;
    }

    // THE ONLY DIFFERENCE between BFS and DFS is this line:
    // BFS takes the oldest cell (front), DFS takes the newest (end).
    var idx = (algo == "bfs") ? 0 : ds_list_size(frontier) - 1;
    var cur = frontier[| idx];
    ds_list_delete(frontier, idx);

    var prev_cell = current;   // the cell visited on the previous step (-1 on the very first step)
    visited[cur] = true;
    current = cur;
    visit_count++;

    if (cur == goal_cell) {
        finish_search(true);
        return;
    }

    var cx   = cur mod cols;
    var cy   = cur div cols;
    var ring = dist[cur];   // BFS: the ring this cell is in.  DFS: how deep the trail is.
    var pos_txt  = "(" + string(cx) + "," + string(cy) + ")";
    var dir_name = ["up", "right", "down", "left"];
    var checks   = "";
    var added    = 0;

    for (var k = 0; k < 4; k++) {
        // DFS checks the directions in reverse so "up" ends on top of the stack
        var d  = (algo == "bfs") ? k : 3 - k;
        var nx = cx + dir_x[d];
        var ny = cy + dir_y[d];
        var nm = dir_name[d];

        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
            checks += nm + ": edge of the map; ";
            continue;
        }

        var nb = ny * cols + nx;
        var nt = nm + " (" + string(nx) + "," + string(ny) + ")";

        if (wall[nb])    { checks += nt + ": wall, blocked; ";                      continue; }
        if (visited[nb]) { checks += nt + ": already explored, never repeat work; "; continue; }

        if (algo == "bfs") {
            if (discovered[nb]) { checks += nt + ": already in the queue; "; continue; }
            discovered[nb] = true;
            checks += nt + ": NEW, joins the back as ring " + string(ring + 1) + "; ";
        } else {
            var old = ds_list_find_index(frontier, nb);
            if (old != -1) {
                ds_list_delete(frontier, old);
                checks += nt + ": was waiting, MOVED to the top (reached from here now); ";
            } else {
                checks += nt + ": NEW, pushed on the stack; ";
            }
        }

        came_from[nb] = cur;
        dist[nb] = dist[cur] + 1;
        ds_list_add(frontier, nb);
        added++;
    }

    // tidy the end of the neighbour text: "...; " becomes "..."
    if (string_length(checks) > 2) checks = string_copy(checks, 1, string_length(checks) - 2) + ".";

    
    var qs = ds_list_size(frontier);
    var nxt_txt = "";
    if (qs > 0) {
        var nn = frontier[| (algo == "bfs") ? 0 : qs - 1];
        nxt_txt = "(" + string(nn mod cols) + "," + string(nn div cols) + ")";
    }
    var cells_txt = string(qs) + ((qs == 1) ? " cell" : " cells");

    // BFS: how many queued cells belong to the next ring
    var ahead = 0;
    for (var m = 0; m < qs; m++) {
        if (dist[frontier[| m]] == ring + 1) ahead++;
    }

    var l1, l3, l4;

    if (algo == "bfs") {
       
        if (ring == 0) {
            l1 = "STEP 1 - BFS RULE: explore in rings. It starts with the start cell, which is ring 0 (0 steps from S).";
        } else {
            l1 = "STEP " + string(visit_count) + " - BFS RULE: finish every cell 1 step from S, then every cell 2 steps away, then 3... BFS takes "
               + pos_txt + ", which is " + string(ring) + ((ring == 1) ? " step" : " steps") + " from S (ring " + string(ring) + ").";
            if (prev_cell != -1 && ring > dist[prev_cell]) {
                l1 += " A NEW RING has begun: every closer cell is already explored.";
            }
        }

        l3 = (qs > 0)
           ? ("The queue holds " + cells_txt + ", all in ring " + string(ring) + " or " + string(ring + 1)
              + ". New cells always join the BACK, so closer cells are always served first. Next up: " + nxt_txt + ".")
           : "The queue is now empty.";

        l4 = (added > 0)
           ? ("Idea: BFS never skips ahead. Ring " + string(ring + 1) + " now has " + string(ahead) + ((ahead == 1) ? " cell" : " cells")
              + " waiting, but none of them is taken until every cell in ring " + string(ring) + " is finished.")
           : ("Idea: nothing new here, and that is fine. BFS is not stuck - it moves on to the next cell in the queue, still finishing ring "
              + string(ring) + " first.");
    } else {
       
        if (prev_cell == -1) {
            l1 = "STEP 1 - DFS RULE: go as deep as possible. It starts at the start cell.";
        } else {
            l1 = "STEP " + string(visit_count) + " - DFS RULE: always continue from the NEWEST cell and go as deep as possible, backing up only at a dead end. DFS takes "
               + pos_txt + ", now " + string(ring) + ((ring == 1) ? " step" : " steps") + " deep in its trail.";
            if (came_from[cur] != prev_cell) {
                l1 += " BACKTRACK: the last trail ended, so DFS jumped back to the newest cell still waiting on the stack (a route it skipped earlier).";
            }
        }

        l3 = (qs > 0)
           ? ("The stack holds " + cells_txt + ". The TOP is the newest, so DFS continues from there: " + nxt_txt
              + ". Cells lower down are skipped routes it only tries if this trail hits a dead end.")
           : "The stack is now empty.";

        l4 = (added > 0)
           ? "Idea: DFS commits to one direction instead of comparing options, so it dives deeper next. That is fast if the trail heads toward G, and wasteful if it heads away."
           : "Idea: DEAD END - nothing new from here. DFS backs up to the last route it skipped and tries that instead. All this backing up is why DFS can waste time.";
    }

    narrate = l1 + "\n" + "It checks its 4 neighbours: " + checks + "\n" + l3 + "\n" + l4;
}

finish_search = function(ok) {
    found = ok;
    mode  = "done";
    route = [];

    if (ok) {
        var p = goal_cell;
        while (p != -1) {
            route[array_length(route)] = p;
            p = came_from[p];
        }
        var steps = array_length(route) - 1;

        narrate = "GOAL REACHED after " + string(visit_count) + " cells explored. The yellow line is the path, " + string(steps)
                + " steps long (the game follows each cell's 'came from' link back to S).\n"
                + ((algo == "bfs")
                   ? "BFS idea: it was working on ring " + string(steps) + " when it touched G. Every closer ring was already finished, so no shorter route can exist - that is why a BFS path is always the shortest."
                   : "DFS idea: it stopped the moment its trail touched G. It never compared other routes, so a shorter path may exist - DFS finds A path, not necessarily the best one.");
    } else {
        narrate = "The list is empty and the goal was never reached.\nEvery cell that could be reached has been explored, so there is NO path from S to G.";
    }

    var len = ok ? (array_length(route) - 1) : -2;
    if (algo == "bfs") {
        bfs_visited = visit_count;
        bfs_len = len;
    } else {
        dfs_visited = visit_count;
        dfs_len = len;
    }
}

// Writes the "why was that method faster?" explanation, using THIS round's real numbers.
explain_result = function() {
    if (bfs_len < 0 || dfs_len < 0) return "G could not be reached, so neither search was faster.";
    if (winner == "tie")            return "Both searches explored exactly the same number of cells this time.";

    var shortest = bfs_len;   // BFS always finds the shortest path

    // where is G compared with S?  (rows count downwards on screen)
    var gdx = (goal_cell mod cols) - (start_cell mod cols);
    var gdy = (goal_cell div cols) - (start_cell div cols);
    var vtxt = (gdy < 0) ? "up" : ((gdy > 0) ? "down" : "");
    var htxt = (gdx > 0) ? "right" : ((gdx < 0) ? "left" : "");
    var where_txt = vtxt;
    if (vtxt != "" && htxt != "") where_txt += " and ";
    where_txt += htxt;

    // DFS's favourite directions are up, then right. How many of them point toward G?
    var fav = ((gdy < 0) ? 1 : 0) + ((gdx > 0) ? 1 : 0);

    var s = "";
    if (winner == "bfs") {
        s = "WHY BFS WAS FASTER: BFS fans out in rings, so it reaches G as soon as it gets to ring " + string(shortest)
          + " (the cells " + string(shortest) + " steps from S) - that took " + string(bfs_visited) + " cells. "
          + "DFS does not know where G is: it dives up, then right, then down, then left, and needed " + string(dfs_visited)
          + " cells (its path was " + string(dfs_len) + " steps against the shortest " + string(shortest) + "). ";
        if (fav == 0) s += "G was " + where_txt + " of S, away from DFS's favourite directions, so its first dives pointed the wrong way.";
        else          s += "G was " + where_txt + " of S, partly in DFS's favourite directions, but its dive still cost it extra cells.";
    } else {
        s = "WHY DFS WAS FASTER: DFS dived deep and hit G after only " + string(dfs_visited) + " cells. "
          + "BFS must finish every ring around S first, and G was " + string(shortest)
          + " steps away - rings get bigger the farther out you go, so that took " + string(bfs_visited) + " cells. ";
        if (fav >= 1) s += "G was " + where_txt + " of S, matching DFS's favourite directions (up, then right). ";
        else          s += "G was " + where_txt + " of S, against DFS's favourite directions, so this was mostly luck. ";
        if (dfs_len > shortest) s += "DFS found G sooner, but its path (" + string(dfs_len) + " steps) is longer than the shortest (" + string(shortest) + ").";
        else                    s += "DFS found G sooner, and its path is also the shortest (" + string(shortest) + " steps).";
    }
    return s;
}

stat_text = function(v) {
    if (v == -1) return "-";
    if (v == -2) return "no path";
    return string(v);
}

// draws text at the layout scale, shrinking it if the line would run off the screen
txt = function(tx, ty, s) {
    var edge  = 10 * ui;
    var avail = (draw_get_halign() == fa_right) ? (tx - edge) : (room_width - tx - edge);
    var w  = string_width(s);
    var sc = ui;
    if (w > 0 && w * ui > avail) sc = avail / w;
    draw_text_transformed(tx, ty, s, sc, sc, 0);
}

// draws wrapped, multi-line text at the layout scale
txt_block = function(tx, ty, s) {
    draw_text_ext_transformed(tx, ty, s, -1, (room_width - 2 * tx) / ui, ui, ui, 0);
}

// ---------- on-screen buttons ----------
btn_begin = function(startx, starty) {
    btn_x = startx;
    btn_y = starty;
}

// draws one button and records a click. Buttons wrap onto a new row if they don't fit.
btn = function(bid, label, enabled) {
    var bw  = string_width(label) * ui + 28 * ui;
    var bh  = 30 * ui;
    var gap = 8 * ui;

    if (btn_x + bw > room_width - 10 * ui) {
        btn_x = 10 * ui;
        btn_y += bh + gap;
    }

    var hover = enabled && point_in_rectangle(mouse_x, mouse_y, btn_x, btn_y, btn_x + bw, btn_y + bh);
    var fill  = enabled ? (hover ? make_colour_rgb(95, 160, 245) : make_colour_rgb(45, 105, 200))
                        : make_colour_rgb(50, 53, 62);

    draw_set_colour(fill);
    draw_roundrect_ext(btn_x, btn_y, btn_x + bw, btn_y + bh, 10 * ui, 10 * ui, false);
    if (enabled) {
        draw_set_colour(c_white);
        draw_roundrect_ext(btn_x, btn_y, btn_x + bw, btn_y + bh, 10 * ui, 10 * ui, true);
    }

    draw_set_colour(enabled ? c_white : make_colour_rgb(120, 124, 136));
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text_transformed(btn_x + bw / 2, btn_y + bh / 2, label, ui, ui, 0);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    if (hover && mouse_check_button_pressed(mb_left)) btn_click = bid;
    btn_x += bw + gap;
}

// Runs a search silently (no drawing) and returns how many cells it visited
// before reaching the goal, or -1 if the goal can't be reached.
simulate = function(which) {
    var vis  = array_create(total, false);
    var disc = array_create(total, false);
    var list = ds_list_create();
    var count  = 0;
    var result = -1;

    ds_list_add(list, start_cell);
    disc[start_cell] = true;

    while (ds_list_size(list) > 0) {
        var idx = (which == "bfs") ? 0 : ds_list_size(list) - 1;
        var cur = list[| idx];
        ds_list_delete(list, idx);

        vis[cur] = true;
        count++;
        if (cur == goal_cell) {
            result = count;
            break;
        }

        var cx = cur mod cols;
        var cy = cur div cols;
        for (var k = 0; k < 4; k++) {
            var d  = (which == "bfs") ? k : 3 - k;
            var nx = cx + dir_x[d];
            var ny = cy + dir_y[d];
            if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
            var nb = ny * cols + nx;
            if (wall[nb] || vis[nb]) continue;

            if (which == "bfs") {
                if (disc[nb]) continue;
                disc[nb] = true;
            } else {
                var old = ds_list_find_index(list, nb);
                if (old != -1) ds_list_delete(list, old);
            }
            ds_list_add(list, nb);
        }
    }

    ds_list_destroy(list);
    return result;
}

// Builds a new random round: walls, start and goal.
new_round = function() {
    var tries = 0;
    var ok = false;

    while (!ok && tries < 200) {
        tries++;

        for (var n = 0; n < total; n++) wall[n] = (random(1) < 0.22);

        start_cell = irandom(total - 1);
        goal_cell  = irandom(total - 1);
        wall[start_cell] = false;
        wall[goal_cell]  = false;

        // keep start and goal reasonably far apart
        var dx = abs((start_cell mod cols) - (goal_cell mod cols));
        var dy = abs((start_cell div cols) - (goal_cell div cols));
        if (dx + dy < 8) continue;

        // must be reachable, and the two algorithms must differ (no ties)
        var rb = simulate("bfs");
        var rd = simulate("dfs");
        if (rb > 0 && rd > 0 && rb != rd) ok = true;
    }

    reset_search();
    bfs_visited = -1;  bfs_len = -1;
    dfs_visited = -1;  dfs_len = -1;
    guess           = "";
    phase_timer     = 0;
    phase           = "predict";
    keyboard_string = "";   // clear whatever the player typed last round
    input_msg       = "";
    result_why      = "";
}

// start the first round
new_round();
