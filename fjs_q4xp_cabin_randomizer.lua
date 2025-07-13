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
    -- FJS already randomizes the windows on aircraft load. We can just take this and use during cruise.
    local CABIN_WINDOW_REF = XPLMFindDataRef("FJS/Q4XP/Manips/CabinWindowShades_Ctl")
    -- Not to be mistaken as the index count. this value minus 1
    local WINDOW_COUNT = 56

    local OVERHEAD_CABINS_REF = XPLMFindDataRef("FJS/Q4XP/Manips/CabinOverheadBins_Ctl")
    OVERHEAD_CABIN_COUNT = 27

    FRONT_ROW_TRAY_REF = XPLMFindDataRef("FJS/Q4XP/Manips/FrontRowSeatTrays_Ctl")
    BACK_SEAT_TRAY_REF = XPLMFindDataRef("FJS/Q4XP/Manips/SeatBackTrays_Ctl")
    BACK_SEAT_TRAY_COUNT = 76

    -- backup the window state on startup
    local init_window_states = XPLMGetDatavf(CABIN_WINDOW_REF, 0, WINDOW_COUNT)

    -- currently does not work as expected
    -- local init_window_states = create_dataref_table("FJS/Q4XP/Manips/CabinWindowShades_Ctl", "FloatArray")
    local open_window_states = {}

    -- The window index to update.
    local current_window = math.random(WINDOW_COUNT)

    -- used to achieve the effect of gradual opening windows
    local window_cycled = {}

    for i = 1, WINDOW_COUNT do
        open_window_states[i] = 0
        window_cycled[i] = 0
    end

    function re_init()
        XPLMSetDatavf(CABIN_WINDOW_REF, init_window_states, 0, WINDOW_COUNT)
        window_cycled = open_window_states
    end

    function update_window_state()
        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")
        save_window_state()

        if seatbelts == 1 then
            XPLMSetDatavf(CABIN_WINDOW_REF, open_window_states, 0, WINDOW_COUNT)
            -- reset all the cycled windows so you can animate again.
            close_overhead_cabins()
            close_passenger_trays()
        end
    end

    -- checks if passenger windows state shows as all open or all closed.
    -- We don't want to accidentally save all the windows in open position although that's perfectly fine.
    -- this also allows the passenger to adjust the blinds while the loop is running
    function save_window_state()
        current_window_states = XPLMGetDatavf(CABIN_WINDOW_REF, 0, WINDOW_COUNT)
        for i = 0, #current_window_states - 1 do
            if
                current_window_states[i] > 0 and
                    window_cycled[current_slice_val] ~= init_window_states[current_slice_val]
             then
                -- Take a new snapshot of the window posistions before opening. The passengers may have adjusted it in between.
                init_window_states[current_slice_val] = window_cycled[current_slice_val]
            end
        end
        window_cycled = XPLMGetDatavf(CABIN_WINDOW_REF, 0, WINDOW_COUNT)
    end

    -- randomly open the overhead cabin during cruise or fasten seatbelts off
    function open_shades_randomly()
        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")
        if seatbelts == 0 then
            random_shade = math.random(WINDOW_COUNT)
            if window_cycled[random_shade] == 0 then
                window_cycled[random_shade] = math.random()
            end
            XPLMSetDatavf(CABIN_WINDOW_REF, window_cycled, 0, WINDOW_COUNT)
        end
    end

    -- randomly open the overhead cabin during cruise or fasten seatbelts off
    function open_overhead_cabins_randomly()
        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")

        if seatbelts == 0 then
            overhead_cabins = XPLMGetDatavf(OVERHEAD_CABINS_REF, 0, OVERHEAD_CABIN_COUNT)
            random_overhead_cabin = math.random(OVERHEAD_CABIN_COUNT)
            overhead_cabins[random_overhead_cabin] = overhead_cabins[random_overhead_cabin] == 0 and 1 or 0
            XPLMSetDatavf(OVERHEAD_CABINS_REF, overhead_cabins, 0, OVERHEAD_CABIN_COUNT)
        end
    end

    function close_overhead_cabins()
        overhead_cabins = {}
        for i = 0, OVERHEAD_CABIN_COUNT - 1 do
            overhead_cabins[i] = 0
        end
        XPLMSetDatavf(OVERHEAD_CABINS_REF, overhead_cabins, 0, OVERHEAD_CABIN_COUNT)
    end

    -- randomly open the overhead cabin during cruise or fasten seatbelts off
    function lower_trays_randomly()
        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")

        if seatbelts == 0 then
            front_row_trays = XPLMGetDatavf(FRONT_ROW_TRAY_REF, 0, 4)
            back_seat_trays = XPLMGetDatavf(BACK_SEAT_TRAY_REF, 0, BACK_SEAT_TRAY_COUNT)

            random_front_tray = math.random(4)
            random_back_seat_tray = math.random(BACK_SEAT_TRAY_COUNT)
            front_row_trays[random_front_tray] = overhead_cabins[random_front_tray] == 0 and 1 or 0
            back_seat_trays[random_back_seat_tray] = back_seat_trays[random_back_seat_tray] == 0 and 1 or 0

            XPLMSetDatavf(FRONT_ROW_TRAY_REF, front_row_trays, 0, 4)
            XPLMSetDatavf(BACK_SEAT_TRAY_REF, back_seat_trays, 0, BACK_SEAT_TRAY_COUNT)
        end
    end

    function close_passenger_trays()
        front_row_trays = {0, 0, 0, 0}
        back_seat_trays = {}
        for i = 0, BACK_SEAT_TRAY_COUNT - 1 do
            back_seat_trays[i] = 0
        end
        XPLMSetDatavf(FRONT_ROW_TRAY_REF, front_row_trays, 0, 4)
        XPLMSetDatavf(BACK_SEAT_TRAY_REF, back_seat_trays, 0, BACK_SEAT_TRAY_COUNT)
    end

    do_often("update_window_state()")
    do_often("open_shades_randomly()")
    do_sometimes("open_overhead_cabins_randomly()")
    do_sometimes("lower_trays_randomly()")
    do_on_exit("re_init()")
end
