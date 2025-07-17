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

    for i = 1, WINDOW_COUNT do
        open_window_states[i] = 0
        window_cycled[i] = 0
    end

    function re_init()
        XPLMSetDatavf(PAX_WINDOW_REF, init_window_states, 0, WINDOW_COUNT)
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

    function random_lavatory()
        toilet_seat = get("FJS/Q4XP/Manips/LavSeat_Ctl", 1)
        set_array("FJS/Q4XP/Manips/LavSeat_Ctl", 1, toilet_seat == 1 and 0 or 1)
        lavatory_front = get("FJS/Q4XP/Manips/CabinInnerDoors_Ctl", 0)
        set_array("FJS/Q4XP/Manips/CabinInnerDoors_Ctl", 0, lavatory_front == 0 and 1 or 0)
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
        DataRef("seatbelts", "sim/cockpit2/annunciators/fasten_seatbelt")

        if seatbelts == 0 then
            front_row_trays = XPLMGetDatavf(FRONT_ROW_TRAY_REF, 0, 4)
            back_seat_trays = XPLMGetDatavf(BACK_SEAT_TRAY_REF, 0, BACK_SEAT_TRAY_COUNT)

            random_front_tray = math.random(4)
            random_back_seat_tray = math.random(BACK_SEAT_TRAY_COUNT)
            front_row_trays[random_front_tray] = overhead_luggage[random_front_tray] == 0 and 1 or 0
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

    -- TODO: FJS/Q4XP/Manips/CabinInnerDoors_Ctl FJS/Q4XP/Manips/LavSeat_Ctl

    do_often("fasten_seatbelt()")
    do_sometimes("lower_shades_randomly()")
    do_sometimes("open_overhead_luggage_randomly()")
    do_sometimes("lower_trays_randomly()")
    do_sometimes("random_lavatory()")
    do_on_exit("re_init()")
    command_once()
end
