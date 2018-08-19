var REAL_ASIDE_MARGIN_LEFT = 1 * 16; // in px

var INITIAL_SIDEBAR_TOP_PADDING = 1 * 16;
var MINIMAL_SIDEBAR_TOP_PADDING = 0;
var INITIAL_SIDEBAR_BOTTOM_PADDING = 0 * 16;
var MINIMAL_SIDEBAR_BOTTOM_PADDING = 0 * 16;

function handleMediaChange(mediaQueryList) {
    var main = document.getElementById("main");
    if (mediaQueryList.matches) {
        var aside = document.getElementById("aside");
        var marginLeft = 0;
        if (aside !== null) {
            marginLeft = aside.offsetWidth + REAL_ASIDE_MARGIN_LEFT;
        }
        var marginLeftString = marginLeft.toString() + "px";
        console.log(marginLeftString);
        main.style.marginLeft = marginLeftString;
    } else {
        main.style.marginLeft = "";
    }
    handleScroll(window.scrollY);
}

function handleScroll(pos) {
    var aside = document.getElementById("aside");
    var header = document.getElementById("header");
    var footer = document.getElementById("footer");
    // var innerContainer = aside.querySelectorAll("div:last-child")[0];
    var mql = window.matchMedia("(min-width: 60rem)");
    if (mql.matches) {
        var topPadding = header.offsetHeight + INITIAL_SIDEBAR_TOP_PADDING - pos;
        console.log(header.offsetHeight);
        if (topPadding < MINIMAL_SIDEBAR_TOP_PADDING) topPadding = MINIMAL_SIDEBAR_TOP_PADDING;
        aside.style.paddingTop = topPadding.toString() + "px";

        var windowHeight = window.innerHeight;
        var documentHeight = document.body.clientHeight;
        var bottomPadding = footer.offsetHeight + INITIAL_SIDEBAR_BOTTOM_PADDING - (documentHeight - windowHeight - pos);
        if (bottomPadding < MINIMAL_SIDEBAR_BOTTOM_PADDING) bottomPadding = MINIMAL_SIDEBAR_BOTTOM_PADDING;
        var height = windowHeight - bottomPadding;
        aside.style.height = height.toString() + "px";
    } else {
        aside.style.paddingTop = "";
        aside.style.height = "";
    }
}

function register() {
    var mql = window.matchMedia("(min-width: 60rem)");
    mql.addListener(handleMediaChange);
    handleMediaChange(mql);

    var last_known_scroll_position = 0;
    var ticking = false;
    window.addEventListener('scroll', function(e) {
        last_known_scroll_position = window.scrollY;
        if (!ticking) {
            window.requestAnimationFrame(function() {
                handleScroll(last_known_scroll_position);
                ticking = false;
            });
            ticking = true;
        }
    });
    window.onhashchange = function() {
        console.log("hash changed");
        console.log(window.scrollY);
        handleScroll(window.scrollY);
    };
}

!function() {
    register();
}()