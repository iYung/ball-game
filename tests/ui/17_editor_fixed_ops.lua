-- A pasted definition with ops = {} and fixed_ops keeps both through Test, Copy and Paste.
local DEFINITION = 'return { name="Fixed", grid_w=10, grid_h=10, source={x=2,y=2}, sink={x=6,y=2},'
    .. ' ops={}, fixed_ops={"flip_v",{op="scalar_mul",params={scalar=-1}}},'
    .. ' input={rows=2,cols=2,values={{1,0},{0,1}}},'
    .. ' target={rows=2,cols=2,values={{1,0},{0,1}}} }'

local steps = {
    { set_clipboard = DEFINITION },
    { click_button = "Editor" },
}

local function add(...)
    for _, s in ipairs({ ... }) do steps[#steps + 1] = s end
end

local function paste_and_test()
    add({ click_button  = { id = "editor:paste" } },
        { click_button  = { id = "editor:test" } },
        { assert_button = { id = "palette:fixed:flip_v", visible = true } },
        { assert_button = { id = "palette:fixed:scalar_mul", visible = true } },
        { assert_text   = "x-1!" },
        { assert_button = { id = "palette:transpose", visible = false } })
end

paste_and_test()
add({ click_button = { id = "cmd:menu" } },
    { click_button = { id = "editor:copy" } },
    { click_button = { id = "editor:back" } },
    { click_button = "Editor" })
paste_and_test()   -- a fresh editor, pasting the copied text

return {
    {
        name  = "fixed ops and empty ops survive Paste, Test and Copy",
        given = { solved = {} },
        steps = steps,
    },
    {
        name  = "pasting an unsupported fixed op shows why",
        given = { solved = {} },
        steps = {
            { set_clipboard = 'return { fixed_ops={"abs"},'
                .. ' input={rows=1,cols=1,values={{1}}}, target={rows=1,cols=1,values={{1}}} }' },
            { click_button = "Editor" },
            { click_button = { id = "editor:paste" } },
            { assert_text  = "Unsupported op: abs" },
        },
    },
}
