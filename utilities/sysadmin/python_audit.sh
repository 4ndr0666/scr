#!/bin/bash
# shellcheck disable=all

# Function to prompt for user input
prompt() {
    local var_name="$1"
    local prompt_message="$2"
    read -p "$prompt_message" "$var_name"
}

# Function to update pyenv
update_pyenv() {
    echo "Updating pyenv..."
    cd ~/.pyenv || exit
    git pull
}

# Function to install the latest Python version using pyenv
install_latest_python() {
    echo "Installing the latest Python version..."
    latest_version=$(pyenv install -l | grep -v - | tail -1)
    pyenv install "$latest_version"
    pyenv global "$latest_version"
}

# Function to set up pyenv-virtualenv
setup_pyenv_virtualenv() {
    echo "Setting up pyenv-virtualenv..."
    git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
    echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
    echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc
    exec "$SHELL"
}

# Function to create and activate a virtual environment
create_virtualenv() {
    prompt ENV_NAME "Enter the name for the new virtual environment: "
    latest_version=$(pyenv versions --bare | tail -1)
    pyenv virtualenv "$latest_version" "$ENV_NAME"
    pyenv activate "$ENV_NAME"
}

# Function to update pip and install pip-tools
update_pip_and_install_tools() {
    echo "Updating pip and installing pip-tools..."
    pip install --upgrade pip
    pip install pip-tools
}

# Function to create a requirements.txt file
create_requirements_file() {
    echo "Creating requirements.txt file..."
    pip freeze > requirements.txt
}

# Function to update packages
update_packages() {
    echo "Updating packages..."
    pip install --upgrade -r requirements.txt
}

# Function to clean up unused packages
clean_unused_packages() {
    echo "Cleaning up unused packages..."
    pip-autoremove -y
}

# Function to set up best practices for Python development
setup_best_practices() {
    echo "Setting up best practices for Python development..."
    latest_version=$(pyenv versions --bare | tail -1)
    echo "$latest_version" > .python-version
    prompt PROJECT_ENV "Enter the name for the project virtual environment: "
    pyenv virtualenv "$latest_version" "$PROJECT_ENV"
    pyenv local "$PROJECT_ENV"
}

# Function to ensure system-wide environment variables and paths
setup_environment_variables() {
    echo "Setting up environment variables..."
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc
    echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc

    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
    echo 'eval "$(pyenv init --path)"' >> ~/.zshrc
    echo 'eval "$(pyenv init -)"' >> ~/.zshrc
    echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc

    exec "$SHELL"
}

# Function to integrate Python RC configuration
integrate_pythonrc() {
    local pythonrc_path="$HOME/.config/pythonrc"
    mkdir -p "$(dirname "$pythonrc_path")"
    echo 'import readline' > "$pythonrc_path"
    echo 'readline.write_history_file = lambda *args: None' >> "$pythonrc_path"
    echo "Python RC configuration integrated at $pythonrc_path"
}

# Main function to perform the audit and optimization
main() {
    # Ensure pyenv is installed
    if ! command -v pyenv &> /dev/null; then
        echo "pyenv not found, installing pyenv..."
        curl https://pyenv.run | bash
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
        echo 'eval "$(pyenv init -)"' >> ~/.bashrc
        exec "$SHELL"
    fi

    update_pyenv
    install_latest_python
    setup_pyenv_virtualenv
    create_virtualenv
    update_pip_and_install_tools
    create_requirements_file
    update_packages
    clean_unused_packages
    setup_best_practices
    setup_environment_variables
    integrate_pythonrc

    echo "Python environment audit and optimization completed successfully."
}

# Execute the main function
main
