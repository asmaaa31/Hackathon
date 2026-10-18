draw_clear(make_colour_rgb(24, 26, 32));
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var col_empty = make_colour_rgb(40, 44, 54);
var col_wall  = make_colour_rgb(95, 100, 118);
var inset = max(1, floor(cell / 32));   // gap between cells
var csc   = cell / 32;                  // scale for the S and G letters


for (var yy = 0; yy < rows; yy++) {
    for (var xx = 0; xx < cols; xx++) {
        var i  = yy * cols + xx;
        var x1 = ox + xx * cell;
        var y1 = yy * cell;

        var col = col_empty;
        if (wall[i]) {
            col = col_wall;
        } else if (visited[i]) {
            col = make_colour_hsv((dist[i] * 12) mod 256, 150, 230);
        }
        draw_set_colour(col);
        draw_rectangle(x1 + inset, y1 + inset, x1 + cell - inset, y1 + cell - inset, false);
    }
}


var sz  = ds_list_size(frontier);
var fin = cell * 0.19;
draw_set_colour(make_colour_rgb(255, 160, 40));
for (var k = 0; k < sz; k++) {
    var f  = frontier[| k];
    var fx = ox + (f mod cols) * cell;
    var fy = (f div cols) * cell;
    draw_rectangle(fx + fin, fy + fin, fx + cell - fin, fy + cell - fin, false);
}

// final path 
if (mode == "done" && found) {
    draw_set_colour(c_yellow);
    for (var k = 0; k < array_length(route); k++) {
        var p  = route[k];
        var qx = ox + (p mod cols) * cell + cell / 2;
        var qy = (p div cols) * cell + cell / 2;
        draw_circle(qx, qy, cell * 0.19, false);
        if (k > 0) {
            var q = route[k - 1];
            draw_line_width(qx, qy, ox + (q mod cols) * cell + cell / 2, (q div cols) * cell + cell / 2, max(2, cell * 0.12));
        }
    }
}

if (mode == "running" && current != -1) {
    var cxp = ox + (current mod cols) * cell;
    var cyp = (current div cols) * cell;
    draw_set_colour(c_white);
    draw_rectangle(cxp + inset, cyp + inset, cxp + cell - inset, cyp + cell - inset, true);
    draw_rectangle(cxp + inset + 1, cyp + inset + 1, cxp + cell - inset - 1, cyp + cell - inset - 1, true);
}

// start and goal 
var sx = ox + (start_cell mod cols) * cell;
var sy = (start_cell div cols) * cell;
var gx = ox + (goal_cell mod cols) * cell;
var gy = (goal_cell div cols) * cell;

draw_set_colour(make_colour_rgb(60, 200, 100));
draw_rectangle(sx + 2 * inset, sy + 2 * inset, sx + cell - 2 * inset, sy + cell - 2 * inset, false);
draw_set_colour(make_colour_rgb(230, 70, 70));
draw_rectangle(gx + 2 * inset, gy + 2 * inset, gx + cell - 2 * inset, gy + cell - 2 * inset, false);

draw_set_colour(c_black);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_text_transformed(sx + cell / 2, sy + cell / 2, "S", csc, csc, 0);
draw_text_transformed(gx + cell / 2, gy + cell / 2, "G", csc, csc, 0);
draw_set_halign(fa_left);
draw_set_valign(fa_top);


var lh       = 22 * ui;                 // line height
var mx       = 10 * ui;                 // left margin
var pt       = grid_h + 10 * ui;        // top of the panel
var box_y    = pt + 9 * lh + 6 * ui;    // frontier boxes / answer box (leaves room for ~8 lines of explanation)
var box_h    = 20 * ui;
var box_step = 22 * ui;
var lab_y    = box_y + box_h + 4 * ui;  // "front / end" labels
var stat_y   = lab_y + lh + 6 * ui;
var last_y   = stat_y + lh;
var ctl_y    = last_y + lh + 8 * ui;    // buttons


var title = "";
var hint  = "";
var tcol  = c_white;
var hcol  = c_gray;

if (quiz) {
    if (phase == "predict") {
        tcol  = make_colour_rgb(120, 220, 255);
        title = "ROUND " + string(rounds + 1) + ":  BFS or DFS - which finds G after exploring FEWER cells?";
        hcol  = make_colour_rgb(225, 230, 245);
        hint  = "HOW TO PLAY\n"
              + "1. Green S is the start, red G is the goal, grey blocks are walls.\n"
              + "2. BFS spreads out evenly in rings. DFS dives down one path and backs up at dead ends.\n"
              + "3. Which one will explore FEWER cells before it reaches G?  Type bfs or dfs below, then press ENTER.\n"
              + "(Quicker = fewer cells explored, not the shortest path.)";
    } else if (phase == "run_bfs" || phase == "run_dfs") {
        var who = (phase == "run_bfs") ? "BFS" : "DFS";
        if (mode == "running" && manual && sz > 0) {
            // tell the player what the NEXT step will do, before they press N
            var nc  = frontier[| (algo == "bfs") ? 0 : sz - 1];
            var ntx = "(" + string(nc mod cols) + "," + string(nc div cols) + ")";
            if (algo == "bfs") title = "NEXT: BFS takes the OLDEST cell " + ntx + " from the front.   Press NEXT STEP or N";
            else               title = "NEXT: DFS takes the NEWEST cell " + ntx + " from the end.   Press NEXT STEP or N";
        } else if (mode == "done" && phase == "run_bfs" && manual) {
            title = "BFS finished!  Press NEXT STEP or N to watch DFS on the same maze.";
        } else {
            title = "Running " + who + "...   (use the AUTOPLAY button for step-by-step)";
        }
    } else if (phase == "result") {
        tcol = correct ? c_lime : c_red;
        var ans = (winner == "tie") ? "a TIE" : string_upper(winner);
        title = (correct ? "CORRECT!  " : "WRONG!  ") + "The answer was " + ans
              + "  (BFS " + string(bfs_visited) + " cells, DFS " + string(dfs_visited) + ")";
        hcol = make_colour_rgb(225, 230, 245);
        hint = result_why + "\n\nPress NEXT ROUND (or ENTER) to play again.";
    }
} else {
    title = "SANDBOX: paint walls with the mouse (right-click erases, S / G move start / goal), then run BFS or DFS";
    if (algo == "bfs") title = "BFS = QUEUE: always take the OLDEST discovered cell (front of the list)";
    if (algo == "dfs") title = "DFS = STACK: always take the NEWEST discovered cell (end of the list)";
}

// detailed live explanation while a search is running
if (mode != "idle" && (!quiz || phase == "run_bfs" || phase == "run_dfs")) {
    hint = narrate;
    hcol = make_colour_rgb(255, 230, 120);
}

draw_set_colour(tcol);
txt(mx, pt, title);
draw_set_colour(hcol);
txt_block(mx, pt + lh, hint);


var maxbox = max(1, floor((room_width - 2 * mx) / box_step));
var shown  = min(sz, maxbox);
var bw     = box_step - 4 * ui;

draw_set_colour(make_colour_rgb(255, 160, 40));
for (var k = 0; k < shown; k++) {
    var bx = mx + k * box_step;
    draw_rectangle(bx, box_y, bx + bw, box_y + box_h, false);
}

var show_next = (!quiz || phase == "run_bfs" || phase == "run_dfs");
if (shown > 0 && show_next) {
    var nk  = (algo == "dfs") ? shown - 1 : 0;
    var nbx = mx + nk * box_step;
    draw_set_colour(c_white);
    draw_rectangle(nbx - 1, box_y - 1, nbx + bw + 1, box_y + box_h + 1, true);
}

var next_front = (show_next && algo == "bfs");
var next_end   = (show_next && algo == "dfs");

draw_set_halign(fa_left);
draw_set_colour(next_front ? c_white : c_gray);
txt(mx, lab_y, next_front ? "front (oldest)  <- NEXT" : "front (oldest)");
draw_set_halign(fa_right);
draw_set_colour(next_end ? c_white : c_gray);
txt(room_width - mx, lab_y, next_end ? "NEXT ->  end (newest)" : "end (newest)");
draw_set_halign(fa_left);


draw_set_colour(c_white);
var status = "";
if (quiz) {
    status = "Score: " + string(score) + "/" + string(rounds) + "    Streak: " + string(streak) + "    ";
}
status += "Visited: " + string(visit_count) + "    Frontier: " + string(sz);
if (!quiz && mode == "done") {
    if (found) status += "    Path length: " + string(array_length(route) - 1);
    else       status += "    NO PATH FOUND";
}
status += manual ? "    STEP-BY-STEP" : ("    AUTOPLAY  Speed: " + string(spd + 1) + "/8");
if (paused) status += "    [PAUSED]";
txt(mx, stat_y, status);

draw_set_colour(c_gray);
txt(mx, last_y, "Last BFS -> visited " + stat_text(bfs_visited) + ", path " + stat_text(bfs_len)
              + "      Last DFS -> visited " + stat_text(dfs_visited) + ", path " + stat_text(dfs_len));


btn_begin(mx, ctl_y);

var can_back = (array_length(undo_stack) > 0) && (mode == "running" || mode == "done") && !(quiz && phase == "result");
var can_next = (mode == "running") || (quiz && phase == "run_bfs" && mode == "done");
var auto_lbl = manual ? "AUTOPLAY: OFF  [A]" : "AUTOPLAY: ON  [A]";

if (quiz) {
    if (phase == "run_bfs" || phase == "run_dfs") {
        btn("back", "< BACK  [BACKSPACE]", can_back);
        btn("next", "NEXT STEP >  [N]",    can_next);
        btn("auto", auto_lbl,              true);
    }
    if (phase == "result") {
        btn("round", "NEXT ROUND  [ENTER]", true);
    }
    btn("mode", "SANDBOX MODE  [TAB]", true);
} else {
    btn("bfs",    "RUN BFS  [B]",         true);
    btn("dfs",    "RUN DFS  [D]",         true);
    btn("back",   "< BACK  [BACKSPACE]",  can_back);
    btn("next",   "NEXT STEP >  [N]",     can_next);
    btn("auto",   auto_lbl,               true);
    btn("reset",  "RESET  [R]",           true);
    btn("clear",  "CLEAR WALLS  [C]",     true);
    btn("random", "RANDOM WALLS  [M]",    true);
    btn("mode",   "QUIZ MODE  [TAB]",     true);
}

if (quiz && phase == "predict") {
    var ax = mx + 140 * ui;
    var aw = 190 * ui;

    draw_set_colour(c_white);
    txt(mx, box_y + 2 * ui, "YOUR ANSWER:");

    draw_set_colour(make_colour_rgb(60, 66, 82));
    draw_rectangle(ax, box_y, ax + aw, box_y + box_h, false);
    draw_set_colour(make_colour_rgb(255, 230, 120));
    draw_rectangle(ax, box_y, ax + aw, box_y + box_h, true);

    draw_set_colour(c_white);
    var cursor = ((current_time mod 1000) < 500) ? "_" : "";
    txt(ax + 8 * ui, box_y + 2 * ui, keyboard_string + cursor);

    if (input_msg != "") {
        draw_set_colour(c_red);
        txt(ax + aw + 14 * ui, box_y + 2 * ui, input_msg);
    } else {
        draw_set_colour(c_gray);
        txt(ax + aw + 14 * ui, box_y + 2 * ui, "type bfs or dfs, then ENTER");
    }
}
