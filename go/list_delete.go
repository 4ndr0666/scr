package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

func main() {
	// ASCII Art
	fmt.Println("\033[0;32m")
	fmt.Println(`  .____     .__           __           .___       .__            __                       .__`)
	fmt.Println(`  |    |    |__|  _______/  |_       __| _/ ____  |  |    ____ _/  |_   ____        ______|  |__`)
	fmt.Println(`  |    |    |  |/  ___/\   __\     / __ |_/ __ \ |  |  _/ __ \\   __\_/ __ \      /  ___/|  |  \`)
	fmt.Println(`  |    |___ |  |\___ \  |  |      / /_/ |\  ___/ |  |__\  ___/ |  |  \  ___/      \___ \ |   Y  \`)
	fmt.Println(`  |_______ \|__|/____  > |__|______\____ | \___  >|____/ \___  >|__|   \___  > /\ /____  >|___|  /`)
	fmt.Println(`          \/         \/     /_____/     \/     \/            \/            \/  \/      \/      \/`)
	fmt.Println("\033[0m")

	// Prompt the user for the path to the list
	fmt.Print("\033[0;32mEnter the path to the list of files you want to delete:\033[0m ")
	reader := bufio.NewReader(os.Stdin)
	_input, _ := reader.ReadString('\n')
	_input = strings.TrimSpace(_input)

	// Check if the file exists
	if _, err := os.Stat(_input); os.IsNotExist(err) {
		fmt.Println("File", _input, "not found.")
		return
	}

	// Ask the user for the mode of operation
	fmt.Println("\033[0;32mChoose an option:")
	fmt.Println("1. Delete files in the list that exist.")
	fmt.Println("2. Delete all files except those in the list.")
	fmt.Print("Enter your choice (1/2): \033[0m")
	choice, _ := reader.ReadString('\n')
	choice = strings.TrimSpace(choice)

	// Confirmation before proceeding
	fmt.Print("\033[0;32mAre you sure you want to proceed with this operation? [y/N]: \033[0m")
	confirm, _ := reader.ReadString('\n')
	confirm = strings.TrimSpace(confirm)
	if !strings.EqualFold(confirm, "y") {
		fmt.Println("Operation cancelled.")
		return
	}

	// Based on the user's choice, perform the operation
	switch choice {
	case "1":
		file, _ := os.Open(_input)
		defer file.Close()

		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := scanner.Text()
			if _, err := os.Stat(line); !os.IsNotExist(err) {
				fmt.Println("Deleting", line, "...")
				os.Remove(line)
			} else {
				fmt.Println("File", line, "not found.")
			}
		}
	case "2":
		filesToKeep := make(map[string]bool)

		file, _ := os.Open(_input)
		defer file.Close()

		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := scanner.Text()
			filesToKeep[line] = true
		}

		dir, _ := os.Getwd()
		files, _ := os.ReadDir(dir)
		for _, f := range files {
			if !filesToKeep[f.Name()] {
				fmt.Println("Deleting", f.Name(), "...")
				os.Remove(f.Name())
			} else {
				fmt.Println("Keeping", f.Name(), "...")
			}
		}
	default:
		fmt.Println("Invalid choice.")
		return
	}

	fmt.Println("Operation completed.")
}

