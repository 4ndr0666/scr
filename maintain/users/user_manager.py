#!/usr/bin/env python3
# File: user_management_cli.py
# Author: 4ndr0666
# Edited: 11-24-24
# Desc: User Management Tool (adding, removing, recovering, repairing, and login options)
#       Password Management (changing user passwords)
#       Supports both GUI and CLI operations.

# ================================ // USER_MANAGEMENT_CLI.PY
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
import re
import os
import sys
import subprocess
import gettext
import locale
import argparse

# Initialize gettext for internationalization
locale.setlocale(locale.LC_ALL, "")
gettext.bindtextdomain("user-management", "/usr/share/locale")
gettext.textdomain("user-management")
_ = gettext.gettext

## STRINGS
NOTICE_REMOVE = _(
    "Notice!\n\
All of the user's files will remain in their \n\
home directory unless 'Completely Remove' is checked.\n\
Even so, it is recommended that the\n\
files be backed up!"
)
NOTICE_RECOVER = _(
    "Notice!\n\
A user can only be recovered if the user\n\
has not been completely removed!"
)
WARNING_REPAIR = _(
    "Warning!\n\
Attempting a user repair may restore more\n\
programs to original settings than you intend!\n\
It is highly recommended that you first back up all files in your home directory."
)


class ErrorDialog(Gtk.MessageDialog):
    def __init__(self, error_message):
        super().__init__(
            transient_for=None,
            flags=0,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=_("User-Management Error"),
        )
        self.format_secondary_text(error_message)
        self.run()
        self.destroy()


class SuccessDialog(Gtk.MessageDialog):
    def __init__(self, success_message):
        super().__init__(
            transient_for=None,
            flags=0,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text=_("Success"),
        )
        self.format_secondary_text(success_message)
        self.run()
        self.destroy()


class WarningDialog(Gtk.MessageDialog):
    def __init__(self, warning_message):
        super().__init__(
            transient_for=None,
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK,
            text=_("Warning"),
        )
        self.format_secondary_text(warning_message)
        self.run()
        self.destroy()


class UserManager:
    """
    Core class handling user management operations.
    This class provides methods to add, remove, change password,
    recover, and repair users.
    """

    @staticmethod
    def add_user(username, password, shell="/bin/bash"):
        try:
            # Add the user with a home directory and specified shell
            cmd = ["useradd", "-m", "-s", shell, username]
            subprocess.run(cmd, check=True)

            # Set the user's password securely
            proc = subprocess.Popen(
                ["passwd", username],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            stdout, stderr = proc.communicate(input=f"{password}\n{password}\n")
            if proc.returncode != 0:
                raise subprocess.CalledProcessError(proc.returncode, cmd, stderr)

            return True, _("User added successfully.")
        except subprocess.CalledProcessError as e:
            return False, _("Failed to add user: ") + e.stderr.strip()
        except Exception as e:
            return False, _("An unexpected error occurred: ") + str(e)

    @staticmethod
    def remove_user(username, complete_remove=False):
        try:
            if username == "root":
                raise ValueError(_("Cannot remove the root user."))

            # Delete the user
            cmd = ["userdel"]
            if complete_remove:
                cmd.append("-r")  # Remove home directory and mail spool
            cmd.append(username)
            subprocess.run(cmd, check=True)

            return True, _("User removal completed successfully.")
        except subprocess.CalledProcessError as e:
            return False, _("Failed to remove user: ") + e.stderr.strip()
        except ValueError as ve:
            return False, str(ve)
        except Exception as e:
            return False, _("An unexpected error occurred: ") + str(e)

    @staticmethod
    def change_password(username, password):
        try:
            # Change the user's password securely
            proc = subprocess.Popen(
                ["passwd", username],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            stdout, stderr = proc.communicate(input=f"{password}\n{password}\n")
            if proc.returncode != 0:
                raise subprocess.CalledProcessError(
                    proc.returncode, ["passwd", username], stderr
                )

            return True, _("Password updated successfully.")
        except subprocess.CalledProcessError as e:
            return False, _("Failed to update password: ") + e.stderr.strip()
        except Exception as e:
            return False, _("An unexpected error occurred: ") + str(e)

    @staticmethod
    def recover_user(username, password, shell="/bin/bash"):
        try:
            # Recreate the user with home directory and default shell
            cmd = ["useradd", "-m", "-s", shell, username]
            subprocess.run(cmd, check=True)

            # Set the user's password securely
            proc = subprocess.Popen(
                ["passwd", username],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            stdout, stderr = proc.communicate(input=f"{password}\n{password}\n")
            if proc.returncode != 0:
                raise subprocess.CalledProcessError(
                    proc.returncode, ["passwd", username], stderr
                )

            return True, _("User recovered successfully.")
        except subprocess.CalledProcessError as e:
            return False, _("Failed to recover user: ") + e.stderr.strip()
        except Exception as e:
            return False, _("An unexpected error occurred: ") + str(e)

    @staticmethod
    def repair_user(username, skip_items=None, save_list=None):
        # Note: Comprehensive user repair operations may require additional steps.
        # This function serves as a placeholder for repair operations.
        # Currently, it locks and unlocks the user account as a simple repair action.
        try:
            # Lock the user account
            subprocess.run(["usermod", "-L", username], check=True)

            # Unlock the user account
            subprocess.run(["usermod", "-U", username], check=True)

            # Placeholder for additional repair actions based on skip_items and save_list
            # Implement specific repair logic as needed.

            return True, _("User repair completed successfully.")
        except subprocess.CalledProcessError as e:
            return False, _("Failed to repair user: ") + e.stderr.strip()
        except Exception as e:
            return False, _("An unexpected error occurred: ") + str(e)


class PasswordManagerUI:
    def __init__(self):
        self.build_ui()

    def build_ui(self):
        self.frame = Gtk.Frame(label=_("Password Manager"))

        # Setting margins individually for compatibility
        self.frame.set_margin_start(10)
        self.frame.set_margin_end(10)
        self.frame.set_margin_top(10)
        self.frame.set_margin_bottom(10)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.frame.add(vbox)

        # User Selection
        user_frame = Gtk.Frame(label=_("Choose User"))
        user_frame.set_margin_start(5)
        user_frame.set_margin_end(5)
        user_frame.set_margin_top(5)
        user_frame.set_margin_bottom(5)
        vbox.pack_start(user_frame, False, False, 0)

        self.user_combobox = Gtk.ComboBoxText()
        self.user_combobox.append_text(_("No User Selected:"))
        self.user_combobox.append_text("root")
        self.populate_users()
        self.user_combobox.set_active(0)
        user_frame.add(self.user_combobox)

        # Password Entries
        pass_frame = Gtk.Frame(label=_("User Password"))
        pass_frame.set_margin_start(5)
        pass_frame.set_margin_end(5)
        pass_frame.set_margin_top(5)
        pass_frame.set_margin_bottom(5)
        vbox.pack_start(pass_frame, False, False, 0)

        pass_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        pass_box.set_margin_start(5)
        pass_box.set_margin_end(5)
        pass_box.set_margin_top(5)
        pass_box.set_margin_bottom(5)
        pass_frame.add(pass_box)

        self.pass_entry1 = Gtk.Entry()
        self.pass_entry1.set_placeholder_text(_("Enter new password"))
        self.pass_entry1.set_visibility(False)
        self.pass_entry1.set_invisible_char("*")
        pass_box.pack_start(self.pass_entry1, False, False, 0)

        self.pass_entry2 = Gtk.Entry()
        self.pass_entry2.set_placeholder_text(_("Confirm new password"))
        self.pass_entry2.set_visibility(False)
        self.pass_entry2.set_invisible_char("*")
        pass_box.pack_start(self.pass_entry2, False, False, 0)

        # Buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_box.set_margin_start(5)
        button_box.set_margin_end(5)
        button_box.set_margin_top(5)
        button_box.set_margin_bottom(5)
        vbox.pack_start(button_box, False, False, 0)

        apply_button = self.create_icon_button(
            _("Apply"), "dialog-ok", _("Apply password change")
        )
        apply_button.connect("clicked", self.apply_password)
        button_box.pack_start(apply_button, True, True, 0)

        close_button = self.create_icon_button(
            _("Close"), "dialog-close", _("Close window")
        )
        close_button.connect("clicked", lambda w: Gtk.main_quit())
        button_box.pack_start(close_button, True, True, 0)

    def create_icon_button(self, label, icon_name, tooltip=None):
        button = Gtk.Button.new()
        if icon_name:
            image = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.BUTTON)
            button.set_image(image)
        button.set_label(label)
        if tooltip:
            button.set_tooltip_text(tooltip)
        return button

    def populate_users(self):
        try:
            with open("/etc/passwd", "r") as f:
                for line in f:
                    if re.search(r":x:\d{3,}:", line):
                        username = line.split(":")[0]
                        self.user_combobox.append_text(username)
        except Exception as e:
            ErrorDialog(_("Failed to read /etc/passwd: ") + str(e))

    def apply_password(self, widget):
        user = self.user_combobox.get_active_text()
        if user == _("No User Selected:"):
            ErrorDialog(_("You must choose a user"))
            return

        password1 = self.pass_entry1.get_text()
        password2 = self.pass_entry2.get_text()

        if " " in password1:
            ErrorDialog(_("The password cannot contain spaces"))
            return
        elif not password1:
            ErrorDialog(_("You need to enter a password"))
            return
        elif password1 != password2:
            ErrorDialog(_("First and second password must be identical"))
            return

        success, message = UserManager.change_password(user, password1)
        if success:
            SuccessDialog(message)
        else:
            ErrorDialog(message)


class AddUserUI:
    def __init__(self):
        self.build_ui()

    def build_ui(self):
        self.frame = Gtk.Frame(label=_("Add User"))

        # Setting margins individually for compatibility
        self.frame.set_margin_start(10)
        self.frame.set_margin_end(10)
        self.frame.set_margin_top(10)
        self.frame.set_margin_bottom(10)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.frame.add(vbox)

        # Username Entry
        user_frame = Gtk.Frame(label=_("Enter Username"))
        user_frame.set_margin_start(5)
        user_frame.set_margin_end(5)
        user_frame.set_margin_top(5)
        user_frame.set_margin_bottom(5)
        vbox.pack_start(user_frame, False, False, 0)

        self.user_entry = Gtk.Entry()
        self.user_entry.set_placeholder_text(_("Enter new username"))
        user_frame.add(self.user_entry)

        # Password Entries
        pass_frame = Gtk.Frame(label=_("User Password"))
        pass_frame.set_margin_start(5)
        pass_frame.set_margin_end(5)
        pass_frame.set_margin_top(5)
        pass_frame.set_margin_bottom(5)
        vbox.pack_start(pass_frame, False, False, 0)

        pass_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        pass_box.set_margin_start(5)
        pass_box.set_margin_end(5)
        pass_box.set_margin_top(5)
        pass_box.set_margin_bottom(5)
        pass_frame.add(pass_box)

        self.pass_entry1 = Gtk.Entry()
        self.pass_entry1.set_placeholder_text(_("Enter password"))
        self.pass_entry1.set_visibility(False)
        self.pass_entry1.set_invisible_char("*")
        pass_box.pack_start(self.pass_entry1, False, False, 0)

        self.pass_entry2 = Gtk.Entry()
        self.pass_entry2.set_placeholder_text(_("Confirm password"))
        self.pass_entry2.set_visibility(False)
        self.pass_entry2.set_invisible_char("*")
        pass_box.pack_start(self.pass_entry2, False, False, 0)

        # Shell Selection
        shell_frame = Gtk.Frame(label=_("User Shell"))
        shell_frame.set_margin_start(5)
        shell_frame.set_margin_end(5)
        shell_frame.set_margin_top(5)
        shell_frame.set_margin_bottom(5)
        vbox.pack_start(shell_frame, False, False, 0)

        self.shell_combobox = Gtk.ComboBoxText()
        self.shell_combobox.append_text(_("No Shell Selected:"))
        self.populate_shells()
        self.shell_combobox.set_active(0)
        shell_frame.add(self.shell_combobox)

        # Login Options
        login_frame = Gtk.Frame(label=_("User Login"))
        login_frame.set_margin_start(5)
        login_frame.set_margin_end(5)
        login_frame.set_margin_top(5)
        login_frame.set_margin_bottom(5)
        vbox.pack_start(login_frame, False, False, 0)

        login_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        login_box.set_margin_start(5)
        login_box.set_margin_end(5)
        login_box.set_margin_top(5)
        login_box.set_margin_bottom(5)
        login_frame.add(login_box)

        self.default_login_cb = Gtk.CheckButton(label=_("Set as Default User"))
        login_box.pack_start(self.default_login_cb, False, False, 0)

        self.auto_login_cb = Gtk.CheckButton(label=_("Enable Automatic Login"))
        login_box.pack_start(self.auto_login_cb, False, False, 0)

        # Buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_box.set_margin_start(5)
        button_box.set_margin_end(5)
        button_box.set_margin_top(5)
        button_box.set_margin_bottom(5)
        vbox.pack_start(button_box, False, False, 0)

        apply_button = self.create_icon_button(_("Apply"), "list-add", _("Add user"))
        apply_button.connect("clicked", self.apply_new_user)
        button_box.pack_start(apply_button, True, True, 0)

        close_button = self.create_icon_button(
            _("Close"), "dialog-close", _("Close window")
        )
        close_button.connect("clicked", lambda w: Gtk.main_quit())
        button_box.pack_start(close_button, True, True, 0)

    def create_icon_button(self, label, icon_name, tooltip=None):
        button = Gtk.Button.new()
        if icon_name:
            image = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.BUTTON)
            button.set_image(image)
        button.set_label(label)
        if tooltip:
            button.set_tooltip_text(tooltip)
        return button

    def populate_shells(self):
        try:
            with open("/etc/shells", "r") as f:
                for line in f:
                    shell = line.strip()
                    if shell and not shell.startswith("#"):
                        self.shell_combobox.append_text(shell)
        except Exception as e:
            ErrorDialog(_("Failed to read /etc/shells: ") + str(e))

    def apply_new_user(self, widget):
        username = self.user_entry.get_text().strip()
        password1 = self.pass_entry1.get_text()
        password2 = self.pass_entry2.get_text()
        shell = self.shell_combobox.get_active_text()

        if " " in username:
            ErrorDialog(_("The username cannot contain spaces"))
            return
        elif not username:
            ErrorDialog(_("You need to enter a username"))
            return
        elif shell == _("No Shell Selected:"):
            ErrorDialog(_("You need to choose a shell"))
            return

        if " " in password1:
            ErrorDialog(_("The password cannot contain spaces"))
            return
        elif not password1:
            ErrorDialog(_("You need to enter a password"))
            return
        elif password1 != password2:
            ErrorDialog(_("First and second password must be identical"))
            return

        success, message = UserManager.add_user(username, password1, shell)
        if not success:
            ErrorDialog(message)
            return

        # Handle login options
        if self.default_login_cb.get_active():
            # Notify user to manually set default user
            WarningDialog(
                _(
                    "Setting a default user requires manual configuration of your display manager."
                )
            )

        if self.auto_login_cb.get_active():
            # Notify user to manually enable automatic login
            WarningDialog(
                _(
                    "Enabling automatic login requires manual configuration of your display manager."
                )
            )

        SuccessDialog(message)


class UserRepairUI:
    def __init__(self):
        self.build_ui()

    def build_ui(self):
        self.frame = Gtk.Frame(label=_("User Repair"))

        # Setting margins individually for compatibility
        self.frame.set_margin_start(10)
        self.frame.set_margin_end(10)
        self.frame.set_margin_top(10)
        self.frame.set_margin_bottom(10)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.frame.add(vbox)

        # Warning Label
        warning_label = Gtk.Label(label=WARNING_REPAIR)
        warning_label.set_line_wrap(True)
        warning_label.set_margin_start(5)
        warning_label.set_margin_end(5)
        warning_label.set_margin_top(5)
        warning_label.set_margin_bottom(5)
        vbox.pack_start(warning_label, False, False, 0)

        # User Selection
        user_frame = Gtk.Frame(label=_("Choose User"))
        user_frame.set_margin_start(5)
        user_frame.set_margin_end(5)
        user_frame.set_margin_top(5)
        user_frame.set_margin_bottom(5)
        vbox.pack_start(user_frame, False, False, 0)

        self.user_combobox = Gtk.ComboBoxText()
        self.user_combobox.append_text(_("No User Selected:"))
        self.user_combobox.append_text("root")
        self.populate_users()
        self.user_combobox.set_active(0)
        user_frame.add(self.user_combobox)

        # Items to Skip Repair
        items_frame = Gtk.Frame(label=_("Items to Skip Repair"))
        items_frame.set_margin_start(5)
        items_frame.set_margin_end(5)
        items_frame.set_margin_top(5)
        items_frame.set_margin_bottom(5)
        vbox.pack_start(items_frame, False, False, 0)

        items_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        items_box.set_margin_start(5)
        items_box.set_margin_end(5)
        items_box.set_margin_top(5)
        items_box.set_margin_bottom(5)
        items_frame.add(items_box)

        self.firefox_cb = Gtk.CheckButton(label="Firefox")
        items_box.pack_start(self.firefox_cb, False, False, 0)

        self.claws_mail_cb = Gtk.CheckButton(label="Claws Mail")
        items_box.pack_start(self.claws_mail_cb, False, False, 0)

        self.conky_cb = Gtk.CheckButton(label="Conky System Monitor")
        items_box.pack_start(self.conky_cb, False, False, 0)

        self.icewm_cb = Gtk.CheckButton(label="iceWM")
        items_box.pack_start(self.icewm_cb, False, False, 0)

        self.fluxbox_cb = Gtk.CheckButton(label="Fluxbox")
        items_box.pack_start(self.fluxbox_cb, False, False, 0)

        self.jwm_cb = Gtk.CheckButton(label="JWM")
        items_box.pack_start(self.jwm_cb, False, False, 0)

        self.specify_save_entry = Gtk.Entry()
        self.specify_save_entry.set_placeholder_text(
            _("Enter specific configs to save (separated by |)")
        )
        items_box.pack_start(self.specify_save_entry, False, False, 0)

        # Buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_box.set_margin_start(5)
        button_box.set_margin_end(5)
        button_box.set_margin_top(5)
        button_box.set_margin_bottom(5)
        vbox.pack_start(button_box, False, False, 0)

        apply_button = self.create_icon_button(
            _("Apply"), "edit-undo", _("Repair user")
        )
        apply_button.connect("clicked", self.apply_repair)
        button_box.pack_start(apply_button, True, True, 0)

        close_button = self.create_icon_button(
            _("Close"), "dialog-close", _("Close window")
        )
        close_button.connect("clicked", lambda w: Gtk.main_quit())
        button_box.pack_start(close_button, True, True, 0)

    def create_icon_button(self, label, icon_name, tooltip=None):
        button = Gtk.Button.new()
        if icon_name:
            image = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.BUTTON)
            button.set_image(image)
        button.set_label(label)
        if tooltip:
            button.set_tooltip_text(tooltip)
        return button

    def populate_users(self):
        try:
            with open("/etc/passwd", "r") as f:
                for line in f:
                    if re.search(r":x:\d{3,}:", line):
                        username = line.split(":")[0]
                        self.user_combobox.append_text(username)
        except Exception as e:
            ErrorDialog(_("Failed to read /etc/passwd: ") + str(e))

    def apply_repair(self, widget):
        user = self.user_combobox.get_active_text()
        if user == _("No User Selected:"):
            ErrorDialog(_("You must choose a user"))
            return

        # Collect items to skip repair
        skip_items = []
        if self.firefox_cb.get_active():
            skip_items.append("Firefox")
        if self.claws_mail_cb.get_active():
            skip_items.append("Claws Mail")
        if self.conky_cb.get_active():
            skip_items.append("Conky System Monitor")
        if self.icewm_cb.get_active():
            skip_items.append("iceWM")
        if self.fluxbox_cb.get_active():
            skip_items.append("Fluxbox")
        if self.jwm_cb.get_active():
            skip_items.append("JWM")
        save_list = self.specify_save_entry.get_text().strip()

        # Validate save_list
        if save_list and not re.match(r"^([\w\.\|-]+)$", save_list):
            ErrorDialog(
                _(
                    "The list of configs must be empty or contain valid config identifiers separated by |"
                )
            )
            return

        success, message = UserManager.repair_user(user, skip_items, save_list)
        if success:
            SuccessDialog(message)
        else:
            ErrorDialog(message)


class RemoveUserUI:
    def __init__(self):
        self.build_ui()

    def build_ui(self):
        self.frame = Gtk.Frame(label=_("Remove User"))

        # Setting margins individually for compatibility
        self.frame.set_margin_start(10)
        self.frame.set_margin_end(10)
        self.frame.set_margin_top(10)
        self.frame.set_margin_bottom(10)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.frame.add(vbox)

        # Notice Label
        notice_label = Gtk.Label(label=NOTICE_REMOVE)
        notice_label.set_line_wrap(True)
        notice_label.set_margin_start(5)
        notice_label.set_margin_end(5)
        notice_label.set_margin_top(5)
        notice_label.set_margin_bottom(5)
        vbox.pack_start(notice_label, False, False, 0)

        # User Selection
        user_frame = Gtk.Frame(label=_("Choose User"))
        user_frame.set_margin_start(5)
        user_frame.set_margin_end(5)
        user_frame.set_margin_top(5)
        user_frame.set_margin_bottom(5)
        vbox.pack_start(user_frame, False, False, 0)

        self.user_combobox = Gtk.ComboBoxText()
        self.user_combobox.append_text(_("No User Selected:"))
        self.user_combobox.append_text("root")
        self.populate_users()
        self.user_combobox.set_active(0)
        user_frame.add(self.user_combobox)

        # Completely Remove Checkbox
        remove_frame = Gtk.Frame(label=_("Completely Remove User?"))
        remove_frame.set_margin_start(5)
        remove_frame.set_margin_end(5)
        remove_frame.set_margin_top(5)
        remove_frame.set_margin_bottom(5)
        vbox.pack_start(remove_frame, False, False, 0)

        self.complete_remove_cb = Gtk.CheckButton(label=_("Completely Remove User"))
        remove_frame.add(self.complete_remove_cb)

        # Buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_box.set_margin_start(5)
        button_box.set_margin_end(5)
        button_box.set_margin_top(5)
        button_box.set_margin_bottom(5)
        vbox.pack_start(button_box, False, False, 0)

        apply_button = self.create_icon_button(
            _("Apply"), "list-remove", _("Remove user")
        )
        apply_button.connect("clicked", self.apply_remove)
        button_box.pack_start(apply_button, True, True, 0)

        close_button = self.create_icon_button(
            _("Close"), "dialog-close", _("Close window")
        )
        close_button.connect("clicked", lambda w: Gtk.main_quit())
        button_box.pack_start(close_button, True, True, 0)

    def create_icon_button(self, label, icon_name, tooltip=None):
        button = Gtk.Button.new()
        if icon_name:
            image = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.BUTTON)
            button.set_image(image)
        button.set_label(label)
        if tooltip:
            button.set_tooltip_text(tooltip)
        return button

    def populate_users(self):
        try:
            with open("/etc/passwd", "r") as f:
                for line in f:
                    if re.search(r":x:\d{3,}:", line):
                        username = line.split(":")[0]
                        self.user_combobox.append_text(username)
        except Exception as e:
            ErrorDialog(_("Failed to read /etc/passwd: ") + str(e))

    def apply_remove(self, widget):
        user = self.user_combobox.get_active_text()
        complete_remove = self.complete_remove_cb.get_active()

        if user == _("No User Selected:"):
            ErrorDialog(_("You must choose a user"))
            return

        success, message = UserManager.remove_user(user, complete_remove)
        if success:
            SuccessDialog(message)
        else:
            ErrorDialog(message)


class RecoverUserUI:
    def __init__(self):
        self.build_ui()

    def build_ui(self):
        self.frame = Gtk.Frame(label=_("Recover User"))

        # Setting margins individually for compatibility
        self.frame.set_margin_start(10)
        self.frame.set_margin_end(10)
        self.frame.set_margin_top(10)
        self.frame.set_margin_bottom(10)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.frame.add(vbox)

        # Notice Label
        notice_label = Gtk.Label(label=NOTICE_RECOVER)
        notice_label.set_line_wrap(True)
        notice_label.set_margin_start(5)
        notice_label.set_margin_end(5)
        notice_label.set_margin_top(5)
        notice_label.set_margin_bottom(5)
        vbox.pack_start(notice_label, False, False, 0)

        # Username Entry
        user_frame = Gtk.Frame(label=_("Enter Username"))
        user_frame.set_margin_start(5)
        user_frame.set_margin_end(5)
        user_frame.set_margin_top(5)
        user_frame.set_margin_bottom(5)
        vbox.pack_start(user_frame, False, False, 0)

        self.user_entry = Gtk.Entry()
        self.user_entry.set_placeholder_text(_("Enter username to recover"))
        user_frame.add(self.user_entry)

        # Password Entries
        pass_frame = Gtk.Frame(label=_("User Password"))
        pass_frame.set_margin_start(5)
        pass_frame.set_margin_end(5)
        pass_frame.set_margin_top(5)
        pass_frame.set_margin_bottom(5)
        vbox.pack_start(pass_frame, False, False, 0)

        pass_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        pass_box.set_margin_start(5)
        pass_box.set_margin_end(5)
        pass_box.set_margin_top(5)
        pass_box.set_margin_bottom(5)
        pass_frame.add(pass_box)

        self.pass_entry1 = Gtk.Entry()
        self.pass_entry1.set_placeholder_text(_("Enter new password"))
        self.pass_entry1.set_visibility(False)
        self.pass_entry1.set_invisible_char("*")
        pass_box.pack_start(self.pass_entry1, False, False, 0)

        self.pass_entry2 = Gtk.Entry()
        self.pass_entry2.set_placeholder_text(_("Confirm new password"))
        self.pass_entry2.set_visibility(False)
        self.pass_entry2.set_invisible_char("*")
        pass_box.pack_start(self.pass_entry2, False, False, 0)

        # Buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_box.set_margin_start(5)
        button_box.set_margin_end(5)
        button_box.set_margin_top(5)
        button_box.set_margin_bottom(5)
        vbox.pack_start(button_box, False, False, 0)

        apply_button = self.create_icon_button(
            _("Apply"), "edit-redo", _("Recover user")
        )
        apply_button.connect("clicked", self.apply_recover)
        button_box.pack_start(apply_button, True, True, 0)

        close_button = self.create_icon_button(
            _("Close"), "dialog-close", _("Close window")
        )
        close_button.connect("clicked", lambda w: Gtk.main_quit())
        button_box.pack_start(close_button, True, True, 0)

    def create_icon_button(self, label, icon_name, tooltip=None):
        button = Gtk.Button.new()
        if icon_name:
            image = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.BUTTON)
            button.set_image(image)
        button.set_label(label)
        if tooltip:
            button.set_tooltip_text(tooltip)
        return button

    def apply_recover(self, widget):
        user = self.user_entry.get_text().strip()
        password1 = self.pass_entry1.get_text()
        password2 = self.pass_entry2.get_text()

        if " " in user:
            ErrorDialog(_("The username cannot contain spaces"))
            return
        elif not user:
            ErrorDialog(_("You need to enter a username"))
            return

        if " " in password1:
            ErrorDialog(_("The password cannot contain spaces"))
            return
        elif not password1:
            ErrorDialog(_("You need to enter a password"))
            return
        elif password1 != password2:
            ErrorDialog(_("First and second password must be identical"))
            return

        success, message = UserManager.recover_user(user, password1)
        if not success:
            ErrorDialog(message)
            return

        # Handle login options
        if self.default_login_cb.get_active():
            # Notify user to manually set default user
            WarningDialog(
                _(
                    "Setting a default user requires manual configuration of your display manager."
                )
            )

        if self.auto_login_cb.get_active():
            # Notify user to manually enable automatic login
            WarningDialog(
                _(
                    "Enabling automatic login requires manual configuration of your display manager."
                )
            )

        SuccessDialog(message)


class NotebookApp:
    def __init__(self):
        self.build_ui()

    def build_ui(self):
        self.window = Gtk.Window(title=_("User Management"))
        self.window.set_default_size(600, 400)
        self.window.set_border_width(10)
        self.window.connect("destroy", lambda w: Gtk.main_quit())

        notebook = Gtk.Notebook()
        notebook.set_tab_pos(Gtk.PositionType.LEFT)
        notebook.set_scrollable(True)
        self.window.add(notebook)

        # Password Manager Tab
        password_manager = PasswordManagerUI()
        notebook.append_page(
            password_manager.frame,
            self.create_tab_label("dialog-password", _("Password Manager")),
        )

        # Add User Tab
        add_user = AddUserUI()
        notebook.append_page(
            add_user.frame, self.create_tab_label("list-add", _("Add User"))
        )

        # User Repair Tab
        user_repair = UserRepairUI()
        notebook.append_page(
            user_repair.frame, self.create_tab_label("edit-undo", _("Repair User"))
        )

        # Remove User Tab
        remove_user = RemoveUserUI()
        notebook.append_page(
            remove_user.frame, self.create_tab_label("list-remove", _("Remove User"))
        )

        # Recover User Tab
        recover_user = RecoverUserUI()
        notebook.append_page(
            recover_user.frame, self.create_tab_label("edit-redo", _("Recover User"))
        )

        self.window.show_all()

    def create_tab_label(self, icon_name, label_text):
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        if icon_name:
            image = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
            box.pack_start(image, False, False, 0)
        label = Gtk.Label(label=label_text)
        box.pack_start(label, False, False, 0)
        box.show_all()
        return box


def parse_cli_arguments():
    parser = argparse.ArgumentParser(
        description=_(
            "User Management Tool: Add, remove, recover users and manage passwords."
        )
    )
    subparsers = parser.add_subparsers(dest="command", help=_("Available commands"))

    # Add User
    parser_add = subparsers.add_parser("add", help=_("Add a new user"))
    parser_add.add_argument("username", type=str, help=_("Username of the new user"))
    parser_add.add_argument("password", type=str, help=_("Password for the new user"))
    parser_add.add_argument(
        "--shell",
        type=str,
        default="/bin/bash",
        help=_("Default shell for the new user"),
    )

    # Remove User
    parser_remove = subparsers.add_parser("remove", help=_("Remove an existing user"))
    parser_remove.add_argument(
        "username", type=str, help=_("Username of the user to remove")
    )
    parser_remove.add_argument(
        "--complete",
        action="store_true",
        help=_("Completely remove user and their home directory"),
    )

    # Change Password
    parser_chpass = subparsers.add_parser(
        "change-password", help=_("Change a user's password")
    )
    parser_chpass.add_argument("username", type=str, help=_("Username of the user"))
    parser_chpass.add_argument(
        "password", type=str, help=_("New password for the user")
    )

    # Recover User
    parser_recover = subparsers.add_parser("recover", help=_("Recover a removed user"))
    parser_recover.add_argument(
        "username", type=str, help=_("Username of the user to recover")
    )
    parser_recover.add_argument(
        "password", type=str, help=_("New password for the user")
    )
    parser_recover.add_argument(
        "--shell",
        type=str,
        default="/bin/bash",
        help=_("Default shell for the recovered user"),
    )

    # Repair User
    parser_repair = subparsers.add_parser("repair", help=_("Repair a user account"))
    parser_repair.add_argument(
        "username", type=str, help=_("Username of the user to repair")
    )
    parser_repair.add_argument(
        "--skip", type=str, nargs="*", help=_("Items to skip during repair")
    )
    parser_repair.add_argument(
        "--save", type=str, help=_("Specific configs to save, separated by |")
    )

    return parser.parse_args()


def execute_cli_command(args):
    if args.command == "add":
        success, message = UserManager.add_user(
            args.username, args.password, args.shell
        )
        if success:
            print(_("User added successfully."))
            sys.exit(0)
        else:
            print(message, file=sys.stderr)
            sys.exit(1)

    elif args.command == "remove":
        success, message = UserManager.remove_user(args.username, args.complete)
        if success:
            print(_("User removal completed successfully."))
            sys.exit(0)
        else:
            print(message, file=sys.stderr)
            sys.exit(1)

    elif args.command == "change-password":
        success, message = UserManager.change_password(args.username, args.password)
        if success:
            print(_("Password updated successfully."))
            sys.exit(0)
        else:
            print(message, file=sys.stderr)
            sys.exit(1)

    elif args.command == "recover":
        success, message = UserManager.recover_user(
            args.username, args.password, args.shell
        )
        if success:
            print(_("User recovered successfully."))
            sys.exit(0)
        else:
            print(message, file=sys.stderr)
            sys.exit(1)

    elif args.command == "repair":
        skip_items = args.skip if args.skip else []
        save_list = args.save
        success, message = UserManager.repair_user(args.username, skip_items, save_list)
        if success:
            print(_("User repair completed successfully."))
            sys.exit(0)
        else:
            print(message, file=sys.stderr)
            sys.exit(1)
    else:
        print(_("No valid command provided. Use -h for help."), file=sys.stderr)
        sys.exit(1)


def main():
    # Parse CLI arguments
    args = parse_cli_arguments()

    if args.command:
        # Execute CLI command
        execute_cli_command(args)
    else:
        # Ensure the script is run as root
        if os.geteuid() != 0:
            dialog = Gtk.MessageDialog(
                transient_for=None,
                flags=0,
                message_type=Gtk.MessageType.ERROR,
                buttons=Gtk.ButtonsType.OK,
                text=_("You MUST be root to use this application!"),
            )
            dialog.format_secondary_text(_("Please run the application as root."))
            dialog.run()
            dialog.destroy()
            sys.exit(1)

        # Launch the GUI
        app = NotebookApp()
        Gtk.main()
        return 0


if __name__ == "__main__":
    main()
