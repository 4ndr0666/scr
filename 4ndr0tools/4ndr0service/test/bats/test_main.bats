#!/usr/bin/env bats

@test "CLI menu exits cleanly when 'Exit' is selected" {
    # Run main.sh and provide '12' (Exit option) as input
    # Use 'printf' to simulate user input
    run bash -c "printf '12\n' | /opt/4ndr0service/main.sh"

    # Assert that the script exited successfully
    [ "$status" -eq 0 ]
    # Assert that the output contains 'Terminated!'
    [[ "$output" == *"Terminated!"* ]]
}

@test "Audit function attempts to fix missing environment variables when --fix is used" {
    # Unset environment variables to ensure fix logic is triggered
    unset LOG_FILE PSQL_HOME MYSQL_HOME SQLITE_HOME MESON_HOME SQL_DATA_HOME SQL_CONFIG_HOME SQL_CACHE_HOME

    # Run main.sh with --fix argument directly
    run /opt/4ndr0service/main.sh --fix

    # Print stderr for debugging if the test fails
    if [ "$status" -ne 0 ]; then
        echo "Stderr: $stderr"
    fi

    # Assert that the script exited successfully
    [ "$status" -eq 0 ]

    # Assert that the output contains messages indicating fixes
    [[ "$output" == *"Fixed: LOG_FILE set to"* ]]
    [[ "$output" == *"Fixed: PSQL_HOME set to"* ]]
    [[ "$output" == *"Fixed: MYSQL_HOME set to"* ]]
    [[ "$output" == *"Fixed: SQLITE_HOME set to"* ]]
    [[ "$output" == *"Fixed: MESON_HOME set to"* ]]
    [[ "$output" == *"Fixed: SQL_DATA_HOME set to"* ]]
    [[ "$output" == *"Fixed: SQL_CONFIG_HOME set to"* ]]
    [[ "$output" == *"Fixed: SQL_CACHE_HOME set to"* ]]
}