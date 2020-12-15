var REAL_ASIDE_MARGIN_LEFT = 1 * 16; // in px

var INITIAL_SIDEBAR_TOP_PADDING = 1 * 16;
var MINIMAL_SIDEBAR_TOP_PADDING = 0;
var INITIAL_SIDEBAR_BOTTOM_PADDING = 0 * 16;
var MINIMAL_SIDEBAR_BOTTOM_PADDING = 0 * 16;

var MEDIA_STRING = "(min-width: 1000px)";

function handleMediaChange(_mediaQueryList) {
    handleScroll(window.scrollY);
}

function handleScroll(pos) {
    var aside = document.getElementById("aside");
    if (!aside) return;
    var header = document.getElementById("header");
    var footer = document.getElementById("footer");
    // var innerContainer = aside.querySelectorAll("div:last-child")[0];
    var mql = window.matchMedia(MEDIA_STRING);
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
    var mql = window.matchMedia(MEDIA_STRING);
    mql.addEventListener("change", handleMediaChange);
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
    window.addEventListener('resize', handleMediaChange);
    window.onhashchange = function() {
        console.log("hash changed");
        console.log(window.scrollY);
        handleScroll(window.scrollY);
    };
}

!function() {
    register();
}()
