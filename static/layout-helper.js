var INITIAL_SIDEBAR_TOP_PADDING = 4 * 16;    // 4rem in px
var MINIMAL_SIDEBAR_TOP_PADDING = 0;         // in px
var INITIAL_SIDEBAR_BOTTOM_PADDING = 4 * 16; // 4rem in px
var MINIMAL_SIDEBAR_BOTTOM_PADDING = 1 * 16;      // in px

function handleMediaChange(mediaQueryList) {
    var main = document.getElementById("main");
    if (mediaQueryList.matches) {
        var aside = document.getElementById("aside");
        var marginLeft = 0;
        if (aside !== null) {
            marginLeft = aside.offsetWidth;
        }
        var marginLeftString = marginLeft.toString() + "px";
        console.log(marginLeftString);
        main.style.marginLeft = marginLeftString;
    } else {
        main.style.marginLeft = "0";
    }
    handleScroll();
}

function handleScroll(_event) {
    var aside = document.getElementById("aside");
    var mql = window.matchMedia("(min-width: 60rem)");
    if (mql.matches) {
        var pos = window.scrollY;
        var topPadding = INITIAL_SIDEBAR_TOP_PADDING - pos;
        if (topPadding < MINIMAL_SIDEBAR_TOP_PADDING) top_padding = MINIMAL_SIDEBAR_TOP_PADDING;
        aside.style.paddingTop = topPadding.toString() + "px";
        var windowHeight = window.innerHeight;
        var documentHeight = document.body.clientHeight;
        var bottomPadding = INITIAL_SIDEBAR_BOTTOM_PADDING - (documentHeight - windowHeight - pos);
        console.log(bottomPadding);
        if (bottomPadding < MINIMAL_SIDEBAR_BOTTOM_PADDING) bottomPadding = MINIMAL_SIDEBAR_BOTTOM_PADDING;
        aside.style.paddingBottom = bottomPadding.toString() + "px";
        console.log("paddingTop: " + aside.style.paddingTop);
        console.log("paddingBottom: " + aside.style.paddingBottom);
    } else {
        aside.style.paddingTop = "0";
        aside.style.paddingBottom = "0";
    }
}

function register() {
    var mql = window.matchMedia("(min-width: 60rem)");
    mql.addListener(handleMediaChange);
    handleMediaChange(mql);

    window.addEventListener('scroll', handleScroll);
}

!function() {
    register();
}()