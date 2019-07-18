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

var i, j, kb, kb2, commands = [], command, found, diff = [], matches = 0, disabled = 0, not_found = 0;

for (i = 0; i < mac_defaults.length; i++) {

    kb = mac_defaults[i];

    // replace "cmd+" with "meta+"
    kb.key = kb.key.replace(/\bcmd\+/g, "meta+");

    command = commands.find(function (c) {
        return c.command == kb.command && has(c, "when") == has(kb, "when") && (!has(c, "when") || c.when == kb.when);
    });

    if (command) {

        command["kb"].push(kb);

    } else {

        command = {
            "command": kb.command,
            "kb": [kb],
            "kb2": []
        };

        if (has(kb, "when"))
            command["when"] = kb.when;

        commands.push(command);

    }

}

for (i = 0; i < commands.length; i++) {

    command = commands[i];

    // first pass: eliminate exact matches
    for (j = 0; j < command.kb.length; j++) {

        kb = command.kb[j];

        found = linux_defaults.find(function (kb2) {
            return kb.key == kb2.key && command.command == kb2.command && has(command, "when") == has(kb2, "when") && (!has(command, "when") || command.when == kb2.when);
        });

        // exact match, so exclude from future searches and proceed
        if (found) {

            kb["matched"] = true;
            found["matched"] = true;
            found.command = "-" + found.command;
            command.kb2.push(found);
            matches++;

        }

    }

    // second pass: disable remaining Linux shortcuts
    for (j = 0; j < linux_defaults.length; j++) {

        kb2 = linux_defaults[j];

        if (command.command == kb2.command && has(command, "when") == has(kb2, "when") && (!has(command, "when") || command.when == kb2.when)) {

            kb2.command = "-" + kb2.command;
            diff.push(kb2);
            command.kb2.push(kb2);
            disabled++;

        }

    }

    // third pass: enable remaining Mac shortcuts
    for (j = 0; j < command.kb.length; j++) {

        kb = command.kb[j];

        if (!has(kb, "matched")) {

            diff.push(kb);
            not_found++;

        }

    }

}

console.log("Matching commands found in linux_defaults, skipped: " + matches);
console.log("Commands with different bindings found in linux_defaults, disabled: " + disabled);
console.log("Commands not found in linux_defaults, added to diff: " + not_found);

diff.sort(function (a, b) { return a.command.replace(/^-/, "").localeCompare(b.command.replace(/^-/, "")); });
commands.sort(function (a, b) { return a.command.localeCompare(b.command); });

fs.writeFile("keybindings-diff.json", JSON.stringify(diff), (err) => { if (err) throw err; });
fs.writeFile("keybindings-commands.json", JSON.stringify(commands), (err) => { if (err) throw err; });
