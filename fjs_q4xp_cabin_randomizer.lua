-- FlyJSim Passenger Cabin Activity Simulator
-- Randomly move cabin assets to simulate passenger activity.
-- Before take off & during descent: Window Shades Up, overhead luggage closed, tray tables stowed.
-- Cruising: Randomly move these items

-- logic
-- check if seatbelt signs are on
-- if on, save the current windows state or any changes in between, open all windows
-- if off, gradually restore all window posistions

-- known limitations
-- if your previous session had all the windows up, this script will have nothing to reference the initial windows states so it all windows will remain up.

if PLANE_ICAO == "DH8D" and PLANE_AUTHOR == "FlyJSim" then
    -- System level vars
    local VERSION = 1.4
    local SETTINGS_FILENAME = "fjsq4xp_activity/settings.ini"
    local IS_WINDOW_DISPLAYED = false
    local LIP = require("LIP")

    -- script level vars

    local timer = os.clock()
    -- FJS already randomizes the windows on aircraft load. We can just take this and use during cruise.
    local PAX_WINDOW_REF = XPLMFindDataRef("FJS/Q4XP/Manips/CabinWindowShades_Ctl")
    -- Not to be mistaken as the index count. this value minus 1
    local WINDOW_COUNT = 56

    local OVERHEAD_LUGGAGE_REF = XPLMFindDataRef("FJS/Q4XP/Manips/CabinOverheadBins_Ctl")
    OVERHEAD_LUGGAGE_COUNT = 27

    FRONT_ROW_TRAY_REF = XPLMFindDataRef("FJS/Q4XP/Manips/FrontRowSeatTrays_Ctl")
    BACK_SEAT_TRAY_REF = XPLMFindDataRef("FJS/Q4XP/Manips/SeatBackTrays_Ctl")
    BACK_SEAT_TRAY_COUNT = 76

    -- backup the window state on startup
    local init_window_states = XPLMGetDatavf(PAX_WINDOW_REF, 0, WINDOW_COUNT)

    -- currently does not work as expected
    -- local init_window_states = create_dataref_table("FJS/Q4XP/Manips/CabinWindowShades_Ctl", "FloatArray")
    local open_window_states = {}

    -- The window index to update.
    local current_window = math.random(WINDOW_COUNT)

    -- used to achieve the effect of gradual opening windows
    local window_cycled = {}

    local ENABLE_TRAY_ACTIVITY = true
    local ENABLE_OVHD_ACTIVITY = true
    local ENABLE_WINDOW_ACTIVITY = true

    -- you may prefer to turn this off as it can be annoying in the long term.
    local ENABLE_LAVATORY_ACTIVITY = true
    -- time between lavatory visits.
    local lav_timer_start = os.clock()
    -- next duration for lavatory use
    local lav_use_next = math.random(60, 300)

    local IS_WINDOW_DISPLAYED = false

    for i = 1, WINDOW_COUNT do
        open_window_states[i] = 0
        window_cycled[i] = 0
    end

    function re_init()
        loadSettings()
        window_cycled = open_window_states
    end

    function fasten_seatbelt()
        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")
        save_window_state()

        if seatbelts == 1 then
            raise_window_shades()
            -- reset all the cycled windows so you can animate again.
            close_overhead_luggage()
            close_passenger_trays()
        end
    end

    -- checks if passenger windows state shows as all open or all closed.
    -- We don't want to accidentally save all the windows in open position although that's perfectly fine.
    -- this also allows the passenger to adjust the blinds while the loop is running
    function save_window_state()
        current_window_states = XPLMGetDatavf(PAX_WINDOW_REF, 0, WINDOW_COUNT)
        for i = 0, #current_window_states - 1 do
            if
                current_window_states[i] > 0 and
                    window_cycled[current_slice_val] ~= init_window_states[current_slice_val]
             then
                -- Take a new snapshot of the window posistions before opening. The passengers may have adjusted it in between.
                init_window_states[current_slice_val] = window_cycled[current_slice_val]
            end
        end
        window_cycled = XPLMGetDatavf(PAX_WINDOW_REF, 0, WINDOW_COUNT)
    end

    -- randomly open the overhead cabin during cruise or fasten seatbelts off
    function lower_shades_randomly()
        if not ENABLE_WINDOW_ACTIVITY then
            raise_window_shades()
            return 
        end

        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")
        if seatbelts == 0 then
            random_shade = math.random(WINDOW_COUNT)
            window_cycled[random_shade] = math.random()
            XPLMSetDatavf(PAX_WINDOW_REF, window_cycled, 0, WINDOW_COUNT)
        end
    end

    -- randomly open the overhead luggage during cruise or fasten seatbelts off
    -- Limit the number of open overhead luggage
    local OVHD_MAX_OPEN = 5
    function open_overhead_luggage_randomly()
        if not ENABLE_OVHD_ACTIVITY then
            close_overhead_luggage()
            return 
        end

        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")

        if seatbelts == 0 then
            ovhd_opened = 0
            random_overhead_luggage = 0
            overhead_luggage = XPLMGetDatavf(OVERHEAD_LUGGAGE_REF, 0, OVERHEAD_LUGGAGE_COUNT)
            open_luggages = {}
            -- count the number of open ovhd luggage doors
            for i = 0, #overhead_luggage-1 do
                if overhead_luggage[i] == 1 then 
                    table.insert(open_luggages, i)
                    ovhd_opened = ovhd_opened + 1
                end
            end

            if ovhd_opened < OVHD_MAX_OPEN and overhead_luggage[random_overhead_luggage] == 0 then
                random_overhead_luggage = math.random(OVERHEAD_LUGGAGE_COUNT)
                overhead_luggage[random_overhead_luggage] = 1
            elseif ovhd_opened >= OVHD_MAX_OPEN then
                random_overhead_luggage = math.random(OVHD_MAX_OPEN)
                overhead_luggage[open_luggages[random_overhead_luggage]] = 0
            end

            XPLMSetDatavf(OVERHEAD_LUGGAGE_REF, overhead_luggage, 0, OVERHEAD_LUGGAGE_COUNT)
        end
    end

    function raise_window_shades()
        open_window_states = XPLMGetDatavf(PAX_WINDOW_REF, 0, WINDOW_COUNT)
        for i = 0, WINDOW_COUNT - 1 do
            if open_window_states[i] > 0 then
                open_window_states[i] = 0
                -- use the event loop to make the behavior look gradual instead of simultaneous.
                break
            end
        end
        XPLMSetDatavf(PAX_WINDOW_REF, open_window_states, 0, WINDOW_COUNT)
    end

    -- someone used the bathroom
    function random_lavatory()
        if not ENABLE_LAVATORY_ACTIVITY then 
            close_lavatory()
            return 
        end

        lav_timer_interval = os.clock() - lav_timer_start
        lavatory_door = get("FJS/Q4XP/Manips/CabinInnerDoors_Ctl", 0)
        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")
        if seatbelts == 0 and lav_timer_interval > lav_use_next then
            toilet_seat = get("FJS/Q4XP/Manips/LavSeat_Ctl", 1)
            set_array("FJS/Q4XP/Manips/LavSeat_Ctl", 1, toilet_seat == 1 and 0 or 1)
            set_array("FJS/Q4XP/Manips/CabinInnerDoors_Ctl", 0, 1)
            command_once("FJS/Q4XP/Animation/flush")
            -- reset for next event
            lav_timer_start = os.clock()
            lav_use_next = math.random(60, 300)
        end
    end

    -- Close lavatory door on next cycle. Don't leave it open. Makes it look natural.
    function close_lavatory()
        -- don't interrupt the animation
        if ENABLE_LAVATORY_ACTIVITY and get("FJS/Q4XP/Manips/CabinInnerDoors_Anim", 0) == 1 then
            set_array("FJS/Q4XP/Manips/CabinInnerDoors_Ctl", 0, 0)
        end
    end

    function close_overhead_luggage()
        overhead_luggage = XPLMGetDatavf(OVERHEAD_LUGGAGE_REF, 0, OVERHEAD_LUGGAGE_COUNT)
        for i = 0, OVERHEAD_LUGGAGE_COUNT - 1 do
            if overhead_luggage[i] == 1 then
                overhead_luggage[i] = 0
                -- use the event loop to make the behavior look gradual instead of simultaneous.
                break
            end
        end
        XPLMSetDatavf(OVERHEAD_LUGGAGE_REF, overhead_luggage, 0, OVERHEAD_LUGGAGE_COUNT)
    end

    -- randomly lower/raise passenger trays during cruise or fasten seatbelts off
    function lower_trays_randomly()
        if not ENABLE_TRAY_ACTIVITY then
            close_passenger_trays()
            return 
        end

        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")

        if seatbelts == 0 then
            front_row_trays = XPLMGetDatavf(FRONT_ROW_TRAY_REF, 0, 4)
            back_seat_trays = XPLMGetDatavf(BACK_SEAT_TRAY_REF, 0, BACK_SEAT_TRAY_COUNT)

            random_front_tray = math.random(4)
            random_back_seat_tray = math.random(BACK_SEAT_TRAY_COUNT)
            front_row_trays[random_front_tray] = front_row_trays[random_front_tray] == 0 and 1 or 0
            back_seat_trays[random_back_seat_tray] = back_seat_trays[random_back_seat_tray] == 0 and 1 or 0

            XPLMSetDatavf(FRONT_ROW_TRAY_REF, front_row_trays, 0, 4)
            XPLMSetDatavf(BACK_SEAT_TRAY_REF, back_seat_trays, 0, BACK_SEAT_TRAY_COUNT)
        end
    end

    function close_passenger_trays()
        front_row_trays = XPLMGetDatavf(FRONT_ROW_TRAY_REF, 0, 4)
        back_seat_trays = XPLMGetDatavf(FRONT_ROW_TRAY_REF, 0, WINDOW_COUNT)
        for i = 0, BACK_SEAT_TRAY_COUNT - 1 do
            if back_seat_trays[i] == 1 then
                back_seat_trays[i] = 0
                -- use the event loop to make the behavior look gradual instead of simultaneous.
                break
            end
        end

        for i = 0, 4 - 1 do
            if front_row_trays[i] == 1 then
                front_row_trays[i] = 0
                -- use the event loop to make the behavior look gradual instead of simultaneous.
                break
            end
        end
        XPLMSetDatavf(FRONT_ROW_TRAY_REF, front_row_trays, 0, 4)
        XPLMSetDatavf(BACK_SEAT_TRAY_REF, back_seat_trays, 0, BACK_SEAT_TRAY_COUNT)
    end

    -- UI Dialog Code
    
    local function saveSettings()
        logMsg("q4xp script: save settings...")
        local newSettings = {}
        newSettings.fjsq4xp = {}
        newSettings.fjsq4xp.TRAYS = ENABLE_TRAY_ACTIVITY
        newSettings.fjsq4xp.OVHD = ENABLE_OVHD_ACTIVITY
        newSettings.fjsq4xp.WINDOWS = ENABLE_WINDOW_ACTIVITY
        newSettings.fjsq4xp.LAVATORY = ENABLE_LAVATORY_ACTIVITY
        LIP.save(SCRIPT_DIRECTORY..SETTINGS_FILENAME, newSettings)
        logMsg("q4xp script: save settings done")
    end

    local function loadSettings()
        logMsg("q4xp script: load settings...")
        local f = io.open(SCRIPT_DIRECTORY..SETTINGS_FILENAME)
        if f == nil then return end

        f:close()
        local settings = LIP.load(SCRIPT_DIRECTORY..SETTINGS_FILENAME)

        if settings.fjsq4xp.TRAYS ~= nil then
            ENABLE_TRAY_ACTIVITY = settings.fjsq4xp.TRAYS
        end

        if settings.fjsq4xp.OVHD ~= nil then
            ENABLE_OVHD_ACTIVITY = settings.fjsq4xp.OVHD
        end

        if settings.fjsq4xp.WINDOWS ~= nil then
            ENABLE_WINDOW_ACTIVITY = settings.fjsq4xp.WINDOWS
        end

        if settings.fjsq4xp.LAVATORY ~= nil then
            ENABLE_LAVATORY_ACTIVITY = settings.fjsq4xp.LAVATORY
        end
        logMsg("q4xp script: load settings done")
    end

    function onBuild(settings_window, x, y)
        imgui.Separator()

        local changed, newval
        changed, newval = imgui.Checkbox("PAX Windows", ENABLE_WINDOW_ACTIVITY)
        if changed then
            ENABLE_WINDOW_ACTIVITY = newval
        end

        changed, newval = imgui.Checkbox("PAX Trays", ENABLE_TRAY_ACTIVITY)
        if changed then
            ENABLE_TRAY_ACTIVITY = newval
        end

        changed, newval = imgui.Checkbox("Overhead Luggage", ENABLE_OVHD_ACTIVITY)
        if changed then
            ENABLE_OVHD_ACTIVITY = newval
        end

        changed, newval = imgui.Checkbox("Lavatory Use", ENABLE_LAVATORY_ACTIVITY)
        if changed then
            ENABLE_LAVATORY_ACTIVITY = newval
        end

        if changed then
            saveSettings()
        end
        imgui.TreePop()
    end

    local winCloseInProgess = false

    function onClose()
        IS_WINDOW_DISPLAYED = false
        winCloseInProgess = false
    end

    function buildWindow()
        if (IS_WINDOW_DISPLAYED) then
            return
        end
        settings_window = float_wnd_create(300, 150, 1, true)

        local leftCorner, height, width = XPLMGetScreenBoundsGlobal()

        float_wnd_set_position(settings_window, width / 2 - 375, height / 2)
        float_wnd_set_title(settings_window, "FlyJSim Q4XP Cabin Activity " .. VERSION)
        float_wnd_set_imgui_builder(settings_window, "onBuild")
        float_wnd_set_onclose(settings_window, "onClose")

        IS_WINDOW_DISPLAYED = true
    end

    function showSettingsWindow()
        if IS_WINDOW_DISPLAYED then
            if not winCloseInProgess then
                winCloseInProgess = true
                float_wnd_destroy(settings_window) -- marks for destroy, destroy is async
            end
            return
        end

        buildWindow()
    end

    loadSettings()
    add_macro("FlyJSim Q4XP Cabin Activity", "buildWindow()")
    create_command("FJS/LUA/ShowCabinActivitySettings", "Show Cabin Actviity Settings", "showSettingsWindow()", "", "")

    do_often("fasten_seatbelt()")
    do_often("close_lavatory()")
    do_sometimes("lower_shades_randomly()")
    do_sometimes("open_overhead_luggage_randomly()")
    do_sometimes("lower_trays_randomly()")
    do_sometimes("random_lavatory()")
    do_on_exit("re_init()")

end
