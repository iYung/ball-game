-- Start screen: Play and Unlock All are reachable through the UI registry.
return {
    {
        name  = "click Play opens level select",
        given = { solved = {} },
        steps = {
            { click_button = "Play" },
            { assert_text = "SELECT PUZZLE" },
        },
    },
    {
        name  = "click Unlock All unlocks world 2",
        given = { solved = {} },
        steps = {
            { click_button = "Unlock All" },
            { press = "right" },
            { assert_text = "WORLD 2: COMBOS" },
        },
    },
}
