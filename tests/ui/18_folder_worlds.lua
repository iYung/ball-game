-- Worlds come from the folder layout: their tabs, puzzles, unlocking and
-- cutscenes, as the player sees them. Shipped puzzles and worlds are found by
-- id, so inserting a level or a world does not move these specs.
local PuzzleLoader = require("lua/game/puzzle_loader")

-- Position of a puzzle id.
local function puzzle(id)
    for n = 1, PuzzleLoader.count() do
        if PuzzleLoader.id(n) == id then return n end
    end
    error("no puzzle with id " .. id)
end

-- World number of a world id.
local function world(id)
    for w = 1, PuzzleLoader.world_count() do
        if PuzzleLoader.world_id(w) == id then return w end
    end
    error("no world with id " .. id)
end

local function tab(id)    return { id = "world:" .. world(id) } end
local function row(id)    return { id = "puzzle:" .. puzzle(id) } end

local function row_visible(id)
    return { assert_button = { id = "puzzle:" .. puzzle(id), visible = true } }
end

local WORLDS = {
    { id = "basics",      name = "Basics",      puzzle = "identity",        title = "Identity Check" },
    { id = "combos",      name = "Combos",      puzzle = "top_only",        title = "Top Only" },
    { id = "advanced",    name = "Advanced",    puzzle = "double_negative", title = "Double Negative" },
    { id = "two_sources", name = "Two Sources", puzzle = "merge_maze",      title = "Merge Maze" },
}

-- Spec 1: one solve in Advanced opens every world up to it and no further.
local partly_open = {
    name  = "a solve in a later world opens the worlds up to it",
    given = { solved = { puzzle("double_negative") } },
    steps = {
        { press = "return" },                       -- title -> level select
        { assert_text = "Basics" },
        { assert_text = "Combos" },
        { assert_text = "Advanced" },
        { assert_no_text = "Two Sources" },         -- locked tabs hide their names
        { assert_button = { id = "world:" .. world("advanced"), enabled = true } },
        { assert_button = { id = "world:" .. world("two_sources"), enabled = false } },
        { click_button = tab("combos") },
        row_visible("top_only"),
        { assert_text = "Top Only" },
        { click_button = tab("advanced") },
        row_visible("double_negative"),
        { click_button = row("double_negative") },
        { assert_no_text = "SELECT PUZZLE" },       -- left level select
        { assert_button = { id = "cmd:run", visible = true } },
        { assert_text = "Double Negative" },
    },
}

-- Spec 2: with everything solved, every folder is a named tab with its puzzles.
local all_open = {
    name  = "every world folder is a tab listing its puzzles",
    given = { solved = "all" },
    steps = { { press = "return" } },
}
for _, w in ipairs(WORLDS) do
    all_open.steps[#all_open.steps + 1] = { assert_text = w.name }
end
for _, w in ipairs(WORLDS) do
    local first = PuzzleLoader.world(world(w.id)).puzzles[1]
    for _, step in ipairs({
        { click_button = tab(w.id) },
        { assert_button = { id = "world:" .. world(w.id), label = w.name, selected = true } },
        { assert_button = { id = "puzzle:" .. first.index, label = first.name, visible = true } },
        { assert_text = first.name },
        row_visible(w.puzzle),
        { assert_text = w.title },
    }) do
        all_open.steps[#all_open.steps + 1] = step
    end
end

-- Spec 3: a world's cutscene is read from its folder and plays once.
local solved = PuzzleLoader.world_indices(world("basics"))
solved[#solved + 1] = puzzle("double_negative")

local cutscene = {
    name  = "advanced cutscene comes from its folder and plays once",
    given = { solved = solved, cutscenes_unseen = { world("advanced") } },
    steps = { { press = "return" } },
}
local previous = world("advanced") - 1              -- the world before Advanced
for _ = 2, previous do                              -- arrow across to it
    cutscene.steps[#cutscene.steps + 1] = { press = "right" }
end
for _, step in ipairs({
    { assert_button = { id = "world:" .. previous, selected = true } },
    { press = "right" },                            -- Advanced -> cutscene starts
    { assert_text = "SYSTEM" },
    { press = "return" },
    { press = "return" },
    { assert_text = "WORLD 3: ADVANCED" },          -- third beat
    { press = "return" },                           -- past the last beat -> level select
    { assert_button = { id = "world:" .. world("advanced"), selected = true } },
    row_visible("double_negative"),
    { press = "left" },
    { assert_button = { id = "world:" .. previous, selected = true } },
    { press = "right" },
    row_visible("double_negative"),
    { assert_no_text = "SYSTEM" },                  -- no replay
}) do
    cutscene.steps[#cutscene.steps + 1] = step
end

return { partly_open, all_open, cutscene }
