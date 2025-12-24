#!/bin/bash

#here are some txt that save task and log will save history type 
TASK_FILE="tasks.txt"
LOG_FILE="task_log.txt"



RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # here it resate color with no color


check_dependencies() {
    local missing_deps=()
    local optional_deps=()
    
    echo -e "${YELLOW}Checking system dependencies...${NC}"
    
    #it is the part that  check for notify-send (for notifications)
    if command -v notify-send &> /dev/null; then
        echo -e "${GREEN}✓${NC} notify-send (libnotify-bin) is installed"
    else
        missing_deps+=("libnotify-bin")
        echo -e "${RED}✗${NC} notify-send (libnotify-bin) is NOT installed"
    fi
    
    #it is the part that  Check for paplay  (PulseAudio sound) 
    if command -v paplay &> /dev/null; then
        echo -e "${GREEN}✓${NC} paplay (PulseAudio) is installed"
    else
        optional_deps+=("pulseaudio-utils")
        echo -e "${YELLOW}○${NC} paplay (PulseAudio) is NOT installed (optional)"
    fi
    
    # Check for aplay (ALSA sound)
    if command -v aplay &> /dev/null; then
        echo -e "${GREEN}✓${NC} aplay (ALSA) is installed"
    else
        optional_deps+=("alsa-utils")
        echo -e "${YELLOW}○${NC} aplay (ALSA) is NOT installed (optional)"
    fi
    
    # Check for speaker-test
    if command -v speaker-test &> /dev/null; then
        echo -e "${GREEN}✓${NC} speaker-test is installed"
    else
        echo -e "${YELLOW}○${NC} speaker-test is NOT installed (optional)"
    fi
    
    # Check for zenity (fallback notifications)
    if command -v zenity &> /dev/null; then
        echo -e "${GREEN}✓${NC} zenity is installed"
    else
        echo -e "${YELLOW}○${NC} zenity is NOT installed (optional)"
    fi
    
    # Check for date command eita date command check er time er jonno
    if command -v date &> /dev/null; then
        echo -e "${GREEN}✓${NC} date command is available"
    else
        echo -e "${RED}✗${NC} date command is NOT available (critical)"
    fi
    
    # Check for notification daemon eita screen e notification ditase ki na eitar jonno check korbo
    if pgrep -x "notification-daemon" > /dev/null || pgrep -x "dunst" > /dev/null || pgrep -x "xfce4-notifyd" > /dev/null; then
        echo -e "${GREEN}✓${NC} Notification daemon is running"
    else
        echo -e "${YELLOW}○${NC} No notification daemon detected (may affect notifications)"
    fi
    
    # Check for sound system 
    if pgrep -x "pulseaudio" > /dev/null || pgrep -x "pipewire" > /dev/null || pgrep -x "alsactl" > /dev/null; then
        echo -e "${GREEN}✓${NC} Sound system is running"
    else
        echo -e "${YELLOW}○${NC} No sound system detected (may affect sound alerts)"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Missing critical dependencies!${NC}"
        echo -e "${RED}Please install: ${missing_deps[*]}${NC}"
        echo ""
        echo "Run these commands:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install ${missing_deps[*]}"
        echo ""
        echo -n "Continue anyway? (y/n): "
        read continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if [ ${#optional_deps[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Optional dependencies missing:${NC}"
        echo -e "${YELLOW}For better experience, consider installing: ${optional_deps[*]}${NC}"
        echo ""
        echo "Run these commands:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install ${optional_deps[*]}"
        echo ""
        echo -n "Press Enter to continue..."
        read
    fi
}

# Function to play alarm sound
play_alarm() {
    echo -e "${YELLOW}Playing alarm sound...${NC}" >&2
    #here i use some method because not all method are working some linux 
    # Method 1: Use paplay with system sound
    if command -v paplay &> /dev/null; then
        if [ -f "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" ]; then
            echo -e "${GREEN}Using paplay with alarm-clock-elapsed.oga${NC}" >&2
            paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null &
            return 0
        elif [ -f "/usr/share/sounds/ubuntu/stereo/dialog-question.ogg" ]; then
            echo -e "${GREEN}Using paplay with dialog-question.ogg${NC}" >&2
            paplay /usr/share/sounds/ubuntu/stereo/dialog-question.ogg 2>/dev/null &
            return 0
        fi
    fi
    
    # Method 2: Use aplay with system sound
    if command -v aplay &> /dev/null; then
        if [ -f "/usr/share/sounds/alsa/Front_Center.wav" ]; then
            echo -e "${GREEN}Using aplay with Front_Center.wav${NC}" >&2
            aplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null &
            return 0
        fi
    fi
    
    # Method 3: Generate beep sound using speaker-test
    if command -v speaker-test &> /dev/null; then
        echo -e "${GREEN}Using speaker-test to generate beep${NC}" >&2
        timeout 1s speaker-test -t sine -f 1000 2>/dev/null &
        return 0
    fi
    
    # Method 4: PC speaker beep (fallback)
    echo -e "${YELLOW}Using PC speaker beep as fallback${NC}" >&2
    for i in {1..5}; do
        echo -ne '\007'
        sleep 0.2
    done
    return 1
}

show_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-critical}"
    
    echo -e "${YELLOW}Showing notification: $title - $message${NC}" >&2
    
    if command -v notify-send &> /dev/null; then
        notify-send -u "$urgency" -i appointment-soon -t 0 "$title" "$message"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Notification sent successfully${NC}" >&2
            return 0
        else
            echo -e "${RED}Failed to send notification${NC}" >&2
        fi
    else
        # Fallback: try zenity
        if command -v zenity &> /dev/null; then
            echo -e "${YELLOW}Using zenity as fallback notification${NC}" >&2
            zenity --warning --title="$title" --text="$message" --width=400 2>/dev/null &
            return 0
        else
            echo -e "${RED}No notification system found!${NC}" >&2
            return 1
        fi
    fi
}


convert_to_24h() {
    local time_12h="$1"
    local period="$2"
    
    # Extract hours and minutes
    local hours=$(echo "$time_12h" | cut -d: -f1)
    local minutes=$(echo "$time_12h" | cut -d: -f2)
    
    # Convert to 24-hour format
    if [[ "$period" == "PM" && "$hours" != "12" ]]; then
        hours=$((10#$hours + 12))
    elif [[ "$period" == "AM" && "$hours" == "12" ]]; then
        hours="00"
    fi
    
    # Format with leading zeros
    printf "%02d:%02d" "$hours" "$minutes"
}



convert_to_12h() {
    local time_24h="$1"
    
    # Extract hours and minutes
    local hours=$(echo "$time_24h" | cut -d: -f1)
    local minutes=$(echo "$time_24h" | cut -d: -f2)
    
    # Determine AM/PM
    local period="AM"
    if [ "$hours" -ge 12 ]; then
        period="PM"
    fi
    
    # Convert to 12-hour format
    if [ "$hours" -gt 12 ]; then
        hours=$((hours - 12))
    elif [ "$hours" -eq 0 ]; then
        hours=12
    fi
    
    # Return formatted time
    echo "${hours}:${minutes} ${period}"
}


display_header() {
    clear
    echo
    echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
    echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
    echo -e "${CYAN}--------  ${YELLOW}TTTTTTTTTTT  AAAAAAAAA   SSSSSSSSS   KKK     KKK${CYAN}   --------${NC}"
    echo -e "${CYAN}--------  ${YELLOW}TTTTTTTTTTT  AAAAAAAAA  SSSSSSSSSSS  KKK    KKK${CYAN}    --------${NC}"
    echo -e "${CYAN}--------      ${YELLOW}TTT      AAA   AAA  SSS          KKK   KKK${CYAN}     --------${NC}"
    echo -e "${CYAN}--------      ${YELLOW}TTT      AAAAAAAAA   SSSSSSSS    KKKKKKK${CYAN}       --------${NC}"
    echo -e "${CYAN}--------      ${YELLOW}TTT      AAAAAAAAA        SSSSS   KKK  KKK${CYAN}     --------${NC}"
    echo -e "${CYAN}--------      ${YELLOW}TTT      AAA   AAA  SSS      SS  KKK   KKK${CYAN}     --------${NC}"
    echo -e "${CYAN}--------      ${YELLOW}TTT      AAA   AAA   SSSSSSSSS   KKK    KKK${CYAN}    --------${NC}"
    echo -e "${CYAN}--------      ${YELLOW}TTT      AAA   AAA    SSSSSSS    KKK     KKK${CYAN}   --------${NC}"
    echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
    echo
    echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
    echo -e "${CYAN}--------  ${RED}RRRRRRRRR   EEEEEEEEE  MMM     MMM  III  NN    NN  DDDDDDDD   EEEEEEEEEEE  RRRRRRRRRR             ${CYAN}    --------${NC}"
    echo -e "${CYAN}--------  ${RED}RRRRRRRRR   EEEEEEEEE  MMMM   MMMM  III  NNN   NN  DDDDDDDDD  EEEEEEEE     RRRR   RRRR ${CYAN}   --------${NC}"
    echo -e "${CYAN}--------  ${RED}RRR   RRR   EEE        MMMMM MMMMM  III  NNNN  NN  DDD   DDD  EEEEE        RRR     RRRR ${CYAN}   --------${NC}"
    echo -e "${CYAN}--------  ${RED}RRRRRRRR    EEEEEEE    MMM MMM MMM  III  NN NN NN  DDD    DDD EEEEEEEE     RRRRRRRRRR ${CYAN}  --------${NC}"
    echo -e "${CYAN}--------  ${RED}RRRRRRR     EEEEEEE    MMM  M  MMM  III  NN  NNNN  DDD    DDD EEEEEEEE     RRRRRRRRR    ${CYAN}  --------${NC}"
    echo -e "${CYAN}--------  ${RED}RRR  RRR    EEE        MMM     MMM  III  NN   NNN  DDD   DDD  EEEEEE       RRR     RRR ${CYAN}   --------${NC}"
    echo -e "${CYAN}--------  ${RED}RRR   RRR   EEEEEEEEE  MMM     MMM  III  NN    NN  DDDDDDDDD  EEEEEEEE     RRR       RRR ${CYAN}   --------${NC}"
    echo -e "${CYAN}--------  ${RED}RRR    RRR  EEEEEEEEE  MMM     MMM  III  NN    NN  DDDDDDDD   EEEEEEEEEEE  RRR        RRR ${CYAN}    --------${NC}"
    echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
    echo -e "${CYAN}--------${NC}                 ${GREEN}REMINDER (Task Reminder System)${NC}                  ${CYAN}--------${NC}"
    echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
    echo
}

show_menu() {
    echo -e "${YELLOW}================================${NC}"
    echo -e "${YELLOW}          MAIN MENU${NC}"
    echo -e "${YELLOW}================================${NC}"
    echo "1. Add New Task"
    echo "2. View All Tasks"
    echo "3. Delete Task"
    echo "4. Mark Task as Complete"
    echo "5. View Completed Tasks"
    echo "6. Start Reminder Service"
    echo "7. Test Notification"
    echo "8. System Diagnostics"
    echo "9. Exit"
    echo -e "${YELLOW}================================${NC}"
    echo -n "Enter your choice [1-9]: "
}

add_task() {
    display_header
    echo -e "${GREEN}--- Add New Task ---${NC}"
    echo ""
    
    echo -n "Enter task description: "
    read task_desc
    
    if [ -z "$task_desc" ]; then
        echo -e "${RED}Task description cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    echo -n "Enter task date (YYYY-MM-DD): "
    read task_date
    
    echo -n "Enter task time (HH:MM in 12-hour format): "
    read task_time_12h
    
    echo -n "Enter AM or PM: "
    read period
    
    #IF user enter time on 24 hour formate then  Convert 12-hour time to 24-hour format
    task_time=$(convert_to_24h "$task_time_12h" "$period")
    
    # Validate date and time format
    if ! date -d "$task_date $task_time" >/dev/null 2>&1; then
        echo -e "${RED}Invalid date or time format!${NC}"
        sleep 2
        return
    fi
    
    echo -n "Set custom reminder time before task? (Y/N, default: 5 minutes): "
    read custom_reminder
    
    if [[ "$custom_reminder" == "Y" || "$custom_reminder" == "y" ]]; then
        echo -n "Enter reminder time in minutes before task: "
        read reminder_min
        if ! [[ "$reminder_min" =~ ^[0-9]+$ ]]; then
            reminder_min=5
        fi
    else
        reminder_min=5
    fi
    
    # Generate unique task ID
    task_id=$(date +%s)
    
    # Save task to file
    echo "$task_id|$task_desc|$task_date|$task_time|$reminder_min|pending" >> "$TASK_FILE"
    
    echo -e "${GREEN}Task added successfully!${NC}"
    echo -e "${CYAN}Task will remind you $reminder_min minutes before scheduled time.${NC}"
    sleep 2
}

# Function to view all tasks
view_tasks() {
    display_header
    echo -e "${GREEN}--- All Pending Tasks ---${NC}"
    echo ""
    
    if [ ! -f "$TASK_FILE" ] || [ ! -s "$TASK_FILE" ]; then
        echo -e "${RED}No tasks found!${NC}"
        echo ""
        echo -n "Press Enter to continue..."
        read
        return
    fi
    
    echo -e "${CYAN}ID\t\tDescription\t\tDate\t\tTime\t\tReminder${NC}"
    echo "--------------------------------------------------------------------------------"
    
    local found=0
    while IFS='|' read -r id desc date time reminder status; do
        if [ "$status" == "pending" ]; then
            # Convert 24-hour time to 12-hour format for display
            time_12h=$(convert_to_12h "$time")
            echo -e "$id\t$desc\t\t$date\t$time_12h\t$reminder min"
            found=1
        fi
    done < "$TASK_FILE"
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}No pending tasks!${NC}"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read
}

delete_task() {
    display_header
    echo -e "${RED}--- Delete Task ---${NC}"
    echo ""
    
    view_tasks_inline
    
    echo -n "Enter task ID to delete: "
    read task_id
    
    if grep -q "^$task_id|" "$TASK_FILE" 2>/dev/null; then
        sed -i "/^$task_id|/d" "$TASK_FILE"
        echo -e "${GREEN}Task deleted successfully!${NC}"
    else
        echo -e "${RED}Task ID not found!${NC}"
    fi
    sleep 2
}

view_tasks_inline() {
    if [ ! -f "$TASK_FILE" ] || [ ! -s "$TASK_FILE" ]; then
        echo -e "${RED}No tasks found!${NC}"
        return
    fi
    
    echo -e "${CYAN}ID\t\tDescription\t\tDate\t\tTime${NC}"
    echo "----------------------------------------------------------------"
    
    while IFS='|' read -r id desc date time reminder status; do
        if [ "$status" == "pending" ]; then
            # Convert 24-hour time to 12-hour format for display
            time_12h=$(convert_to_12h "$time")
            echo -e "$id\t$desc\t\t$date\t$time_12h"
        fi
    done < "$TASK_FILE"
    echo ""
}

mark_complete() {
    display_header
    echo -e "${GREEN}--- Mark Task as Complete ---${NC}"
    echo ""
    
    view_tasks_inline
    
    echo -n "Enter task ID to mark as complete: "
    read task_id
    
    if grep -q "^$task_id|" "$TASK_FILE" 2>/dev/null; then
        sed -i "s/^\($task_id|.*|\)pending$/\1completed/" "$TASK_FILE"
        sed -i "s/^\($task_id|.*|\)reminded$/\1completed/" "$TASK_FILE"
        echo -e "${GREEN}Task marked as complete!${NC}"
    else
        echo -e "${RED}Task ID not found!${NC}"
    fi
    sleep 2
}


view_completed() {
    display_header
    echo -e "${GREEN}--- Completed Tasks ---${NC}"
    echo ""
    
    if [ ! -f "$TASK_FILE" ] || [ ! -s "$TASK_FILE" ]; then
        echo -e "${RED}No tasks found!${NC}"
        echo ""
        echo -n "Press Enter to continue..."
        read
        return
    fi
    
    echo -e "${CYAN}ID\t\tDescription\t\tDate\t\tTime${NC}"
    echo "----------------------------------------------------------------"
    
    local found=0
    while IFS='|' read -r id desc date time reminder status; do
        if [ "$status" == "completed" ]; then
            # Convert 24-hour time to 12-hour format for display
            time_12h=$(convert_to_12h "$time")
            echo -e "$id\t$desc\t\t$date\t$time_12h"
            found=1
        fi
    done < "$TASK_FILE"
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}No completed tasks!${NC}"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read
}

test_notification() {
    display_header
    echo -e "${GREEN}--- Testing Notification System ---${NC}"
    echo ""
    echo "Sending test notification with sound..."
    
    show_notification "🔔 Task Reminder Test" "If you can see this pop-up and hear sound, the system is working!" "normal"
    play_alarm
    
    echo -e "${GREEN}Test notification sent!${NC}"
    echo "If you didn't see a pop-up or hear sound, check the installation:"
    echo "  sudo apt-get install libnotify-bin pulseaudio-utils"
    echo ""
    echo -n "Press Enter to continue..."
    read
}

run_diagnostics() {
    display_header
    echo -e "${GREEN}--- System Diagnostics ---${NC}"
    echo ""
    
    check_dependencies
    
    echo ""
    echo -e "${YELLOW}Testing notification system...${NC}"
    if show_notification "🔔 Diagnostic Test" "This is a test notification" "normal"; then
        echo -e "${GREEN}✓ Notification system is working${NC}"
    else
        echo -e "${RED}✗ Notification system is not working${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Testing sound system...${NC}"
    if play_alarm; then
        echo -e "${GREEN}✓ Sound system is working${NC}"
    else
        echo -e "${RED}✗ Sound system is not working${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Task file status:${NC}"
    if [ -f "$TASK_FILE" ]; then
        echo -e "${GREEN}✓ Task file exists at $TASK_FILE${NC}"
        if [ -s "$TASK_FILE" ]; then
            task_count=$(grep -c "pending" "$TASK_FILE" 2>/dev/null || echo "0")
            echo -e "${GREEN}✓ Task file contains $task_count pending tasks${NC}"
        else
            echo -e "${YELLOW}○ Task file is empty${NC}"
        fi
    else
        echo -e "${YELLOW}○ Task file does not exist yet (will be created when needed)${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Log file status:${NC}"
    if [ -f "$LOG_FILE" ]; then
        echo -e "${GREEN}✓ Log file exists at $LOG_FILE${NC}"
        if [ -s "$LOG_FILE" ]; then
            log_lines=$(wc -l < "$LOG_FILE")
            echo -e "${GREEN}✓ Log file contains $log_lines entries${NC}"
        else
            echo -e "${YELLOW}○ Log file is empty${NC}"
        fi
    else
        echo -e "${YELLOW}○ Log file does not exist yet (will be created when needed)${NC}"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read
}



start_reminder_service() {
    display_header
    echo -e "${GREEN}--- Reminder Service Started ---${NC}"
    echo -e "${CYAN}Monitoring tasks for reminders...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    # Create a temporary file to track reminded tasks in this session
    local reminded_file="/tmp/task_reminded_$$.txt"
    touch "$reminded_file"
    
    while true; do
        current_time=$(date +%s)
        
        if [ -f "$TASK_FILE" ]; then
            while IFS='|' read -r id desc date time reminder status; do
                if [ "$status" == "pending" ]; then
                    task_timestamp=$(date -d "$date $time" +%s 2>/dev/null)
                    
                    if [ $? -eq 0 ]; then
                        reminder_time=$((task_timestamp - (reminder * 60)))
                        
                        # Check if it's time to remind and hasn't been reminded in this session
                        if [ $current_time -ge $reminder_time ] && [ $current_time -lt $task_timestamp ]; then
                            # Check if already reminded in this session
                            if ! grep -q "^$id$" "$reminded_file" 2>/dev/null; then
                                # Convert 24-hour time to 12-hour format for display
                                time_12h=$(convert_to_12h "$time")
                                
                                echo -e "\n${RED}========================================${NC}"
                                echo -e "${RED}🔔 REMINDER ALERT! 🔔${NC}"
                                echo -e "${RED}========================================${NC}"
                                echo -e "${YELLOW}Task: $desc${NC}"
                                echo -e "${YELLOW}Scheduled: $date $time_12h${NC}"
                                echo -e "${YELLOW}(In $reminder minutes)${NC}"
                                echo -e "${RED}========================================${NC}\n"
                                
                                # Show desktop notification
                                show_notification "🔔 Task Reminder!" "Task: $desc\nScheduled: $date $time_12h\n(In $reminder minutes)" "critical"
                                
                                # Play alarm sound
                                play_alarm
                                
                                # Log the reminder
                                echo "$(date): Reminded for task: $desc at $date $time" >> "$LOG_FILE"
                                
                                # Mark as reminded in session
                                echo "$id" >> "$reminded_file"
                                
                                # Update task status to avoid repeated reminders
                                sed -i "s/^\($id|.*|\)pending$/\1reminded/" "$TASK_FILE"
                            fi
                        fi
                        
                        # Auto-complete past tasks
                        if [ $current_time -gt $task_timestamp ]; then
                            if [ "$status" == "reminded" ]; then
                                sed -i "s/^\($id|.*|\)reminded$/\1completed/" "$TASK_FILE"
                            fi
                        fi
                    fi
                fi
            done < "$TASK_FILE"
        fi
        
        sleep 30  #this is my checking part that will check  every 30 seconds
    done
    
    # Cleanup
    rm -f "$reminded_file"
}

# Main program loop
main() {
    # Check dependencies on first run
    check_dependencies
    
    while true; do
        display_header
        show_menu
        read choice
        
        case $choice in
            1) add_task ;;
            2) view_tasks ;;
            3) delete_task ;;
            4) mark_complete ;;
            5) view_completed ;;
            6) start_reminder_service ;;
            7) test_notification ;;
            8) run_diagnostics ;;
            9)
                display_header
                echo -e "${GREEN}Thank you for using Task Reminder!${NC}"
                echo -e "${CYAN}Stay organized and productive!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice! Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}


main
