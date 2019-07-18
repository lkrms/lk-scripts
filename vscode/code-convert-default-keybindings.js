'use strict';

const fs = require("fs");

function has(object, key) {

    return object ? hasOwnProperty.call(object, key) : false;

}

var mac_defaults = [
    // put your macOS default keybindings.json here
];

var linux_defaults = [
    // put your Linux default keybindings.json here
];

var i, j, kb, kb2, commands = [], command, found, diff = [], matches = 0, disabled = 0, not_found = 0, skipped = 0, found_in_linux;

for (i = 0; i < mac_defaults.length; i++) {

    kb = mac_defaults[i];

    // replace "cmd+" with "meta+"
    kb.key = kb.key.replace(/\bcmd\+/g, "meta+");

    command = commands.find(function (c) {
        return c.command == kb.command && has(c, "when") == has(kb, "when") && (!has(c, "when") || c.when == kb.when);
    });

    if (command) {

        command.kb.push(kb);

    } else {

        command = {
            "command": kb.command,
            "kb": [kb],
            "kb2": []
        };

        if (has(kb, "when"))
            command.when = kb.when;

        commands.push(command);

    }

}

for (i = 0; i < commands.length; i++) {

    found_in_linux = false;

    command = commands[i];

    // first pass: eliminate exact matches
    for (j = 0; j < command.kb.length; j++) {

        kb = command.kb[j];

        found = linux_defaults.filter(function (kb2) {
            return kb.key == kb2.key && kb2.command.charAt(0) != "-" && command.command == kb2.command && has(command, "when") == has(kb2, "when") && (!has(command, "when") || command.when == kb2.when);
        });

        // exact match, so exclude from future searches and proceed
        if (found.length) {

            kb.matched = true;
            found.forEach(function (f) {
                f.matched = true;
                f.command = "-" + f.command;
            });
            Array.prototype.push.apply(command.kb2, found);
            matches++;
            found_in_linux = true;

        }

    }

    // second pass: disable remaining Linux shortcuts
    linux_defaults.forEach(function (kb2) {

        if (kb2.command.charAt(0) != "-" && command.command == kb2.command && has(command, "when") == has(kb2, "when") && (!has(command, "when") || command.when == kb2.when)) {

            kb2.command = "-" + kb2.command;
            diff.push(kb2);
            command.kb2.push(kb2);
            disabled++;
            found_in_linux = true;

        }

    });

    // third pass: enable remaining Mac shortcuts (unless the command doesn't even exist on Linux)
    for (j = 0; j < command.kb.length; j++) {

        kb = command.kb[j];

        if (!has(kb, "matched")) {

            if (found_in_linux) {

                diff.push(kb);
                not_found++;

            } else {

                skipped++;

            }

        }

    }

}

console.log("Matching commands found in linux_defaults, skipped: " + matches);
console.log("Commands with different bindings found in linux_defaults, disabled: " + disabled);
console.log("Commands not matched in linux_defaults, added to diff: " + not_found);
console.log("Commands not present in linux_defaults, skipped: " + skipped);

diff.sort(function (a, b) { return a.command.replace(/^-/, "").localeCompare(b.command.replace(/^-/, "")); });
commands.sort(function (a, b) { return a.command.localeCompare(b.command); });

fs.writeFile("keybindings-diff.json", JSON.stringify(diff), (err) => { if (err) throw err; });
fs.writeFile("keybindings-commands.json", JSON.stringify(commands), (err) => { if (err) throw err; });
