/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the 'bugs' JavaScript toy.
 *
 * The Initial Developer of the Original Code is
 * Gervase Markham.
 * Portions created by the Initial Developer are Copyright (C) 2008
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * ***** END LICENSE BLOCK ***** */

// Inspired by http://javascript.internet.com/games/ants.html
// which was written by Mike Hall <MHall75819@aol.com>.

// Version 1.1

var START_BUGS = 5;  // number of bugs to begin with
var STEP       = 3;  // pixels per move
var FPS        = 20; // frames per second 
var INERTIA    = 5;  // how long bug continues in one direction before change

// Mouse absolute position in viewport
var mX = 0;
var mY = 0;

var paused = false;
var bugs = new Array();

/*
var imgURLs = [["antul.png", "antup.png", "antur.png"], 
               ["antlt.png", "OOPS",      "antrt.png"], 
               ["antdl.png", "antdn.png", "antdr.png"]];
*/

/* Images from http://javascript.internet.com/games/ants.html */
var imgURLs = [["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAMAAABFNRROAAAAAXNSR0IArs4c6QAAAEhQTFRFpaWlAAAACAgIEBAQGBgYISEhKSkpMTExOTk5QkJCSkpKUlJSa2trc3NzjIyMlJSUnJyctbW1vb29xsbGzs7O1tbW3t7e5%2BfnTCR2jAAAAAF0Uk5TAEDm2GYAAABpSURBVAjXVY4LDoAwCENB5%2FygUxyw%2B99UpjPRJoQCLykAVQYf5d9iF7DSfFmGuaj36nXFjpjBxCexrY9hJJaHFCbEkE5VraylzuGjelAVobHHuLYQZZ4Q4%2FlE5AwOh6PdPCoRvZ%2FdwV4XqpsE8DcqU5UAAAAASUVORK5CYII%3D",        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAMAAABFNRROAAAAAXNSR0IArs4c6QAAAE5QTFRFABkAAAAACAgIEBAQGBgYISEhKSkpMTExOTk5QkJCUlJSa2trc3NzjIyMlJSUnJycpaWltbW1vb29xsbGzs7O1tbW3t7e5%2Bfn7%2B%2Fv9%2Ff3GHESDQAAAAF0Uk5TAEDm2GYAAABuSURBVAjXZY1ZEsMwCEMlN0vjNosNLvb9L1ritF%2FRwAwDTwKApmrVcsElmxle%2BCuTHNtvNmzTIiils6KRPJI1P3tJIBfrYFXZBzKqR59gti0Mmj0bSN5PcjU5SfdV90V89PrRRvLd913pMRvu%2BgIMewUUcjWN3AAAAABJRU5ErkJggg%3D%3D",              "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAMAAABFNRROAAAAAXNSR0IArs4c6QAAAEhQTFRFpaWlAAAACAgIEBAQGBgYISEhKSkpMTExOTk5QkJCSkpKUlJSa2trc3NzjIyMlJSUnJyctbW1vb29xsbGzs7O1tbW3t7e5%2BfnTCR2jAAAAAF0Uk5TAEDm2GYAAABqSURBVAjXRY5BDsIwDATXbUgBl1A3Xuf%2FPyUkovi0I400BuYFrvvOelEL%2BPu3AbbH7dkGecBMF9k52E23lNdXOEieJYmo%2BTB5dG0pMbzYs6ybupOdzixyN%2BMMHKlrqHUGoFp6lPjn0cZnH6lFBPAGVoTyAAAAAElFTkSuQmCC"],
["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAMAAABFNRROAAAAAXNSR0IArs4c6QAAAE5QTFRFABkAAAAACAgIEBAQGBgYISEhKSkpMTExOTk5QkJCUlJSa2trc3NzjIyMlJSUnJycpaWltbW1vb29xsbGzs7O1tbW3t7e5%2Bfn7%2B%2Fv9%2Ff3GHESDQAAAAF0Uk5TAEDm2GYAAABtSURBVAjXZY1ZDoQwDEOdsg0dlmlTSHv%2Fi45LET9YsZToWTFQVTJCQVMEktq1JsAUGhsIFkl2Q67RPMnmXb993BAYExlFxNEdmZOZW09PZN9Bf7NPq1%2Bsvi%2F8lGJrODjGHj3v9oOUxeW5suGtP%2BmwBRReWAt8AAAAAElFTkSuQmCC", "OOPS",          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAMAAABFNRROAAAAAXNSR0IArs4c6QAAAE5QTFRFABkAAAAACAgIEBAQGBgYISEhKSkpMTExOTk5QkJCUlJSa2trc3NzjIyMlJSUnJycpaWltbW1vb29xsbGzs7O1tbW3t7e5%2Bfn7%2B%2Fv9%2Ff3GHESDQAAAAF0Uk5TAEDm2GYAAABtSURBVAjXbU5bDsMwCDNZu7bZ%2Bkhgg9z%2FonMbqV%2BzZMnGyAAQHmgfXGgGlNvhqzA4XR94NWeKSvnOq%2BXl0PHlwCQiA7lICuBBlcinCLMypnkbUt5kivNCwHc1VDZdqArlmvULTM76%2FkxBNPzBD%2F95BRSouZ%2BcAAAAAElFTkSuQmCC"],
["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAMAAABFNRROAAAAAXNSR0IArs4c6QAAAEhQTFRFpaWlAAAACAgIEBAQGBgYISEhKSkpMTExOTk5QkJCSkpKUlJSa2trc3NzjIyMlJSUnJyctbW1vb29xsbGzs7O1tbW3t7e5%2BfnTCR2jAAAAAF0Uk5TAEDm2GYAAABoSURBVAjXRY4LDoAwCENB5%2Fygczhg97%2BpOM1sUtKGlwCAq1Qfj5vUUyJ6Sy0F0oAhfzvmBTFeT1QRmkeMuzXQHBsoa%2BOECTGkS1VB7BhjmImlcbo7xgwm74FtWqv%2B508B669AcVtvPd7aLwTw95DZpwAAAABJRU5ErkJggg%3D%3D",              "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAMAAABFNRROAAAAAXNSR0IArs4c6QAAAE5QTFRFABkAAAAACAgIEBAQGBgYISEhKSkpMTExOTk5QkJCUlJSa2trc3NzjIyMlJSUnJycpaWltbW1vb29xsbGzs7O1tbW3t7e5%2Bfn7%2B%2Fv9%2Ff3GHESDQAAAAF0Uk5TAEDm2GYAAABsSURBVAjXXY1LAsIgDERnsLW21SoQOnD%2FixopK98qnzcJ4Gi5RVw04EnO7ersxEaG2udA1ot8uO%2B2gGRTOJSyb2o0c3N6Z6s9qdVzuedaU%2FyQm%2F1ElFKQ1%2FsBpfFxJjlqZw9cNOqSVOWn8c8X3L0FFMdU3nsAAAAASUVORK5CYII%3D",            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAMAAABFNRROAAAAAXNSR0IArs4c6QAAAEhQTFRFpaWlAAAACAgIEBAQGBgYISEhKSkpMTExOTk5QkJCSkpKUlJSa2trc3NzjIyMlJSUnJyctbW1vb29xsbGzs7O1tbW3t7e5%2BfnTCR2jAAAAAF0Uk5TAEDm2GYAAABrSURBVAjXTY0JDsMwCASXxHXakroh5vj%2FT%2BsjlbISSAMjLQBEn4oZ5tLIJhyJloJaY9CZiZ4i18%2F3TOvGqjYOdvDSZO%2BqmZ0lEbHodFV4S3n9eGd1iDR5t5jlFq%2FHO67%2BcOgX%2F3ibilt87B%2FY2QTwHp402QAAAABJRU5ErkJggg%3D%3D"]];
                
// Preload images
var throwAway = new Image();
for (var i = 0; i < imgURLs.length; i++) {
  for (var j = 0; j < imgURLs[0].length; j++) {
    throwAway.src = imgURLs[i][j];
  }
}

// Bug object - represents one bug
function Bug() {
  // Deal with the fact that some of these properties have "px" on the end
  // Also, make the centre of the bug the centre of the image, not the
  // top left.
  this.getX = function() {
    return this.x;
  }
  
  this.setX = function(x) {
    this.x = x;
    this.img.style.left = (x - this.halfWidth);
  }
  
  this.getY = function() {
    return this.y;
  }
  
  this.setY = function(y) {
    this.y = y;
    this.img.style.top = (y - this.halfHeight);
  }
  
  this.placeRandomly = function() {
    this.setX(Math.floor(Math.random() * document.body.clientWidth));
    this.setY(Math.floor(Math.random() * document.body.clientHeight));
  }
  
  this.imgIndex = function(val) {
    return (val > 0 ? 2 : (val < 0 ? 0 : 1));
  }
  
  this.moveAgain = function() {
    this.move(this.dX, this.dY);
  }

  // tryMove == not an absolute move. You may not get exactly what you ask for.
  // Contains code to make turning circle and to implement inertia.
  this.tryMove = function(tryX, tryY) {
    // Inertia
    if (this.inertia > 0) {
      this.moveAgain();
      this.inertia--;
      return;
    }
      
    // Function to help us only turn a certain amount per move  
    var move1Towards = function(curN, tryN) {
      if (tryN > curN) {
        return ++curN;
      }
      else if (tryN < curN) {
        return --curN;
      }
      else {
        // This shouldn't happen
        return curN;
      }
    }

    // Default to same direction
    var actX = this.dX;
    var actY = this.dY;
    
    if (!((tryX == actX) && (tryY == actY))) {
      var diffX = Math.abs(tryX - actX);
      var diffY = Math.abs(tryY - actY);

      // These together have the effect of moving the bug round to the next
      // compass point.
      if (diffX == 0) {
        actY = move1Towards(this.dY, tryY);
       }
      else if (diffY == 0) {
        actX = move1Towards(this.dX, tryX);
      }
      else if (diffX > diffY) {
        actY = move1Towards(this.dY, tryY);
       }
      else if (diffY > diffX) {
        actX = move1Towards(this.dX, tryX);
      }
      else {
        // Totally wrong direction - reverse
        actX = tryX;
        actY = tryY;
      }
    }
    
    this.move(actX, actY);
    this.inertia = INERTIA;
  }
  
  // A real move - parameters are 0, 1 or -1.
  this.move = function(dX, dY) {
    this.dX = dX;
    this.dY = dY;
    this.setX(this.getX() + (dX * STEP));
    this.setY(this.getY() + (dY * STEP));
    this.img.src = imgURLs[this.imgIndex(dY)][this.imgIndex(dX)];
  }
  
  // Constructor code
  this.img = document.createElement("img");
  this.img.setAttribute("src", imgURLs[0][0]);
  this.img.setAttribute("style", "position: absolute");
  document.body.appendChild(this.img);
  
  // Initialise fields
  this.dX = 1;
  this.dY = 1;
  this.halfWidth = this.img.clientWidth / 2;
  this.halfHeight = this.img.clientHeight / 2;
  this.inertia = Math.ceil(Math.random() * INERTIA);
  this.placeRandomly();
}

function moveBugs() {
  if (!paused) {
    for (var i = 0; i < bugs.length; i++) {
      var bug = bugs[i];
      
      // decide which direction to go
      var offsetX = mX - bug.getX();
      var offsetY = mY - bug.getY();

      // Put the bug somewhere else random if it catches the cursor
      if (Math.abs(offsetX) < (INERTIA * STEP / 2) && 
          Math.abs(offsetY) < (INERTIA * STEP / 2)) 
      {
        bug.placeRandomly();
      }
      
      var dX = offsetX < 0 ? -1 : (offsetX > 0 ? 1 : 0);
      var dY = offsetY < 0 ? -1 : (offsetY > 0 ? 1 : 0);
      bug.tryMove(dX, dY);      
    }
  }
}

function onload() {
  // quit if this function has already been called
  // Otherwise, SeaMonkey 1.2 seems to call this twice
  if (arguments.callee.done) { return };

  // flag this function so we don't do the same thing twice
  arguments.callee.done = true;
  
  // Create a few bugs
  for (var i = 0; i < START_BUGS; i++) {
    bugs.push(new Bug);
  }
  
  window.setInterval(moveBugs, (1000 / FPS));
}

// Defining these event handlers automatically installs them for the entire 
// page. Neat.
function onmousemove(e) {
  // Stash for use when the timer fires
  mX = e.clientX;
  mY = e.clientY;
}

function onmouseover() {
  paused = false;
}

function onmouseout() {
  paused = true;
}

function onclick() {
  bugs.push(new Bug);
}

// onload event doesn't fire on multipart/x-mixed-replace
window.setTimeout(onload, 200);
