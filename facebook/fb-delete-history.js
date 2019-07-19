// WARNING: THE CODE BELOW DELETES EVERYTHING UP TO AND INCLUDING 2015. Filtering is coming.
//
// To halt deletion, close the relevant browser tab. There is NO review process.
//
// 1. go to an activity log (yours or a page's)
// 2. optionally, filter by "Posts", "Videos", etc.
// 3. run this in your browser console
// 4. be patient and click nothing
//

var wait = function (ms) {

    return new Promise(function (resolve, reject) {

        setTimeout(resolve, ms);

    });

}

var scrollToBottom = async function (node) {

    var scrollContainer = node || document.body;
    var currentHeight = 0;
    var retries = 0;

    do {

        await wait(200);

        if (scrollContainer.scrollHeight > currentHeight) {

            retries = 0;

            currentHeight = scrollContainer.scrollHeight;

            window.scrollTo(0, currentHeight);

            console.log("Scrolling to: " + currentHeight);

        } else {

            retries++;

        }

    } while (retries <= 5);

    console.log("Can't scroll any further.");

};

// scroll without clicking a year for starters
await scrollToBottom();

// click each year and scroll
var years = Array.from(document.querySelectorAll(".fbTimelineLogScrubber > li > a"));

while (years.length) {

    years.shift().click();
    await scrollToBottom();

}

// expand all "See more" links
Array.from(document.getElementsByClassName("see_more_link_inner")).forEach(function (el) { el.click(); });

// retrieve all edit buttons
var buttons = Array.from(document.querySelector(".fbTimelineLogBody").querySelectorAll("a[role=\"button\"][data-tooltip-content=\"Edit\"], a[role=\"button\"][data-tooltip-content^=\"Allowed on Page\"]"));

mainLoop:
for (var eb of buttons) {

    var tr = eb;

    while (tr && tr.tagName !== "TR") {

        tr = tr.parentElement;

    }

    if (!tr) {

        continue;

    }

    var permalink = tr.querySelectorAll("a[href^=\"/\"]");

    if (!permalink.length) {

        continue;

    }

    permalink = Array.from(permalink).pop();

    var date = new Date(permalink.innerHTML);

    if (isNaN(date)) {

        continue;

    }

    var content = tr.querySelector("td:nth-child(2) div:last-of-type");

    if (content) {

        content = content.innerText;

    }

    // TODO: implement filters here
    if (date.getFullYear() <= 2015) {

        tr.parentElement.scrollIntoView();

        await wait(200);

        eb.click();

        await wait(200);

        var postId = permalink.href.match(/([0-9]+)(:[0-9]+)?\/?$/), db, db2;

        if (eb.dataset.tooltipContent.match(/^Allowed on Page/)) {

            if (!postId) {

                continue;

            }

            postId = postId[1];

            db = document.querySelector("a[ajaxify^=\"/ajax/timeline/delete/confirm\"][ajaxify*=\"" + postId + "\"]");

            db.click();

            await wait(5000);

            db2 = document.querySelector("form[action^=\"/ajax/timeline/delete\"][action*=\"" + postId + "\"] button[type=\"submit\"]");

            if (!db2) {

                break mainLoop;

            }

            db2.click();

            await wait(2000);

            console.log("Post deleted: ", postId);

        } else if (eb.dataset.tooltipContent == "Edit") {

            if (postId) {

                postId = postId[1];

            } else {

                postId = "";

            }

            db = document.querySelectorAll("a[ajaxify^=\"/ajax/timeline/all_activity/remove_content.php\"]" + (postId ? "[ajaxify*=\"" + postId + "\"]" : ""));

            if (db.length) {

                db = Array.from(db).pop();

                db.click();

                await wait(3000);

            } else {

                postId = permalink.href;

                // can't easily retrieve a meaningful post ID here, so we rely on DOM order instead
                db = Array.from(document.querySelectorAll("a[ajaxify^=\"/ajax/timeline/delete/confirm\"]")).pop();

                db.click();

                await wait(5000);

                db2 = Array.from(document.querySelectorAll("form[action^=\"/ajax/timeline/delete\"] button[type=\"submit\"]")).pop();

                if (!db2) {

                    break mainLoop;

                }

                db2.click();

            }

            await wait(2000);

            console.log("Post deleted: ", postId);

        }

    }

}

