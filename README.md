# Swiper

A touch (and mouse) slider for swiping through images and HTML.


## Browser Support

Swiper supports all [browsers supported by Dart 1.6 and later]
(https://www.dartlang.org/support/faq.html#browsers-and-compiling-to-javascript).


## Features

* **Touch and Mouse.** Slide either on a touch screen or with the mouse.
* **Smooth Transitions.** Swiper uses [Hardware-accelerated CSS3 transitions]
(http://blog.teamtreehouse.com/increase-your-sites-performance-with-hardware-accelerated-css) 
for smooth animations. 
* **Auto Resizing.** When the browser window is resized or a mobile device is 
rotated, the swiper and all its pages are resized automatically. 
* **Scroll Prevention.** Swiper detects if the user tries to slide or tries to 
scroll vertically.
* **Images or HTML.** Swiper supports any HTML content for swipe pages.


## Usage

### 1. HTML

Swiper needs a simple HTML structure. Here is an example:

```HTML
<div class="swiper">
  <div class="page-container">
    <div></div>
    <div></div>
    <div></div>
  </div>
</div>
```

* The `swiper` is the main container. This will become the viewport.
* The `page-container` is the container that wraps all pages.
* The inner `div`s are the slide pages and can contain any HTML content.


### 2. Initialize the Swiper

In the Dart code you initialize the Swiper with a single line. The main 
container needs to be passed to the `Swiper` constructor.

```Dart
Swiper swiper = new Swiper(querySelector('.swiper'));
```


### 3. CSS

A few styles are needed:

```CSS
.swiper {
  overflow: hidden;
  position: relative;
  height: 333px; /* Declare the height of the swiper. */
  visibility: hidden; /* Hide until layout is ready. */
}

.page-container {
  position: relative;
  height: 100%;
}

.page-container > div {
  position: absolute;
  width: 100%;
}
```


## Options

### Soon..

TODO...


## Attribution

Swiper is heavily inspiried by [flipsnap.js](https://github.com/pxgrid/js-flipsnap/), 
[swipe.js](https://github.com/bradbirdsall/Swipe), and
[SwipeView](https://github.com/cubiq/SwipeView).

Many thanks to the authors for those great JavaScript projects! 


## License
The MIT License (MIT)