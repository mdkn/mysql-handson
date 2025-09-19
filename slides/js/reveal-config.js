// Reveal.js configuration
Reveal.initialize({
    hash: true,
    controls: true,
    progress: true,
    center: true,
    transition: 'slide',

    // More settings
    width: 1200,
    height: 700,
    margin: 0.1,
    minScale: 0.2,
    maxScale: 1.5,

    // Keyboard bindings
    keyboard: {
        13: 'next', // go to the next slide when the ENTER key is pressed
        27: function() {}, // do something custom when ESC is pressed
        32: null // don't do anything when SPACE is pressed (i.e. disable a reveal.js default binding)
    },

    // Presentation mode
    showSlideNumber: 'all',
    slideNumber: 'c/t',

    // Plugins
    plugins: [ RevealMarkdown, RevealHighlight, RevealNotes ]
});

// Custom navigation
document.addEventListener('keydown', function(event) {
    // 'h' for home (index)
    if (event.key === 'h' || event.key === 'H') {
        window.location.href = 'index.html';
    }
});

// Auto-advance fragments
Reveal.on('ready', function(event) {
    // Custom initialization if needed
});

// Print mode optimization
if (window.location.search.match(/print-pdf/gi)) {
    Reveal.configure({
        controls: false,
        progress: false,
        transition: 'none'
    });
}