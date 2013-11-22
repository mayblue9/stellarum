// Starmap display methods

var width, height, cx, cy, R;

var nodes;

var position = [ 0, 0 ];

var stars_moving = 0;

var SPIN_TIME = 1000;

var STAR_THRESHOLD = 400;
var STAR_OPACITY = 1;

var RFACTOR = .9;

var CURSOR_RADIUS = 13;
var CURSOR_XY = CURSOR_RADIUS / 1.414213562;

var history = [];

var current_star = false;
var centre_star = false;

// General 3D rotation functions

function rad2deg(rad) {
    return 180 * rad / Math.PI;
}

function deg2rad(deg) {
    return Math.PI * deg / 180;
}


function rotate2(vect2, theta) {
    var c = Math.cos(theta);
    var s = Math.sin(theta);

    var rvect = [ c * vect2[0] - s * vect2[1], s * vect2[0] + c * vect2[1] ];
    
    return rvect;
}

function rotate3(vect3, ra, dec) {
    var rvect3 = [ 0, 0, 0 ];
    var vect2 = rotate2([ vect3[0], vect3[1] ], ra);

    rvect3 = [ vect2[0], vect2[1], vect3[2] ];
    vect2 = rotate2( [ rvect3[0], rvect3[2] ], dec );
    
    rvect3[0] = vect2[0];
    rvect3[2] = vect2[1];
    
    return rvect3
}

// projection_isometric(d, coords) -
//
// d = a star; coords = stellar coordinates for the current star
//
// Takes D's unit vector, rotates it by coords, then does an isometric
// projection to the plane and returns a 'translate(x, y)' string.


function projection_isometric(d, coords) {
    var rvect = rotate3(
	    [ d.vector.x, d.vector.y, d.vector.z ],
	    coords[0], coords[1]
    );
    x = cx + R * rvect[1];
    y = cy + R * rvect[2];
    z = R * rvect[0];
    d.x = x;
    d.y = y;
    d.z = z;
    
    return "translate(" + x + "," + y + ")";
}


// The first magnitude -> radius  function

function magnitude_f(d) {
    var size = 10 / Math.sqrt(1.5 + d.magnitude * .5);
    if ( size < 2 ) {
	    size = 2;
    }
    return size;
}



function make_gc_interp(a, b) {
    var interp = d3.geo.interpolate(
	    [ rad2deg(a[0]), rad2deg(a[1]) ],
	    [ rad2deg(b[0]), rad2deg(b[1]) ]
    );
    
    return function(t) {
	    var p = interp(t);
	    return [ deg2rad(p[0]), deg2rad(p[1]) ];
    }
}

function gc_position_tween(d, gc_interp) {
    return function(t) {
	    return projection_isometric(d, gc_interp(t))
    }
}

function opacity_tween(d, gc_interp) {
    return function(t) {
	    projection_isometric(d, gc_interp(t));
	    return star_opacity(d);
    }
}


function star_opacity(d) {
    if( d.z < -STAR_THRESHOLD ) {
	    return 0;
    }
    if( d.z > STAR_THRESHOLD ) {
	    return STAR_OPACITY;
    }
    return 0.5 * STAR_OPACITY * (d.z + STAR_THRESHOLD) / STAR_THRESHOLD;
}


// select_star(star, spin_time)
//
// Rotates the sphere from the current position (stored in the
// global 'position') to the coords [ -star.ra, -star.dec ] (which
// centre the selected star.
//
// Uses the d3.geo interpolation toolkit so that the star's tween
// paths are great circles, which makes the sphere look realistic.
//
// How it works:
//
// gc_interp is a great circle interpolator function from one set
// of position coordinates to another.
//
// Each star gets its own position tween by passing its datum and
// gc_interp into gc_position_tween.  The tween function returned
// by this returns the actual transform for the move.
//
// Each star also gets an opacity tween function from opacity_tween.
// This changes the opacity based on the z-coordinate (far stars are
// fainter) for the same set of coordinates. 
//
// The tween functions are then passed to the nodes (which are svg groups
// and control the position) and the circles (for the opacity).
//
// A separate set of transition/tween functions f


function select_star(star, spin_time) {

    new_spinner(star, spin_time);
    return;

    gc_interp = make_gc_interp(position, [ -star.ra, -star.dec ]);
    
    var duration = 0;

    duration = spin_time;

    stars_moving = 1;
    current_star = star;
    
    $("div#about").hide();
    $(".pointer").hide();

    nodes.transition()
	    .duration(duration)
	    .attrTween("transform", function(d, i, a) {
	        return gc_position_tween(d, gc_interp)
	    });
    
    d3.selectAll("circle.star")
	    .transition()
	    .duration(duration)
	    .styleTween("opacity", function(d, i, a) {
	        return opacity_tween(d, gc_interp)
	    })
	    .each("end", function(e) {
	        d3.select(this).each(function(d, i) {
		        if( d.id == star.id ) {
                    hide_star_text();
		            show_star_text(d);
		            stars_moving = 0;
                    $(".pointer").show();
		        }
	        });
	    });
    
    position = [ -star.ra, -star.dec ];
}



////////////////////////////// NEW TRANSITIONS /////////////////////

// generalised transition function.
//
// interp_f(d) - interpolator factory function: returns a tween
//               function (t => the star datum) for a given star

function stars_transition(interp_f, duration, after_f) {

    stars_moving = 1;
    
    nodes.transition()
	    .duration(duration)
	    .attrTween("transform", function(d, i, a) {
            var startween = interp_f(d);
            return function(t) {
                var s = startween(t);
                return "translate(" + s.x + "," + s.y + ")";
            }
        });

    d3.selectAll("circle.star")
	    .transition()
	    .duration(duration)
	    .styleTween("opacity", function(d, i, a) {
            var startween = interp_f(d);
            return function(t) {
                var s = startween(t);
                return star_opacity(s);
            }
        })
	    .each("end", after_f);
 
    stars_moving = 0;
}



function new_spinner(star, spintime) {

    var start, finish;

    if( centre_star ) {
        start = [ centre_star.ra, centre_star.dec ];
    } else {
        start = [ 0, 0 ];
    }

    finish = [ star.ra, star.dec ];

    var great_circle = d3.geo.interpolate(
	    [ rad2deg(-start[0]), rad2deg(-start[1]) ],
	    [ rad2deg(-finish[0]), rad2deg(-finish[1]) ]
    );

    // tween_f = tween factory: for each star returns a tween
    // function t => star datum
    
    var tween_f = function(d) {
        return function(t) {
            coords = great_circle(t);
            var rvect = rotate3(
	            [ d.vector.x, d.vector.y, d.vector.z ],
	            deg2rad(coords[0]), deg2rad(coords[1])
            );
            x = cx + R * rvect[1];
            y = cy + R * rvect[2];
            z = R * rvect[0];
            d.x = x;
            d.y = y;
            d.z = z;
            return d;
        }
    };

    centre_star = star;
    
    $("div#about").hide();
    $(".pointer").hide();

    stars_transition(tween_f, spintime, function(e) {
	    d3.select(this).each(function(d, i) {
		    if( d.id == star.id ) {
                hide_star_text();
		        show_star_text(d);
                $(".pointer").show();
		    }
	    });
	});
    
}

// new_gc_interp(start, finish)
// 
// Create an interpolater factory function which returns an interpolator

function new_gc_interp(start, finish) {

}
    








function show_star_text(d) {
    $("div#text").removeClass("O B A F G K M C P W S start");
    $("input#starname").removeClass("O B A F G K M C P W S start");
    $("div#text").addClass(d.class);
    $("input#starname").addClass(d.class);
    $("div#text").removeClass("hidden");
    $("input#starname").val(d.name);
    $("div#stardesignation").text(d.designation);
    $("div#description").html(d.text);
    /* $("div#coords").html(d.id); */ 
    
    /* TODO: lines from links to circles? */
    
    $("span.link").each(
        function (index) {
            var starid = $(this).attr('star');
            var star = stars[starid];
            if( star ) {
                console.log("Link for " + starid + " : " + star.name);
                $(this).click(
                    function(e) {
                        select_star(star, SPIN_TIME);
                    }
                )
            } else {
                console.log("Warning: star " + starid + " not found");
            }
        }
    );

}


function hide_star_text() {
    $("div#text").addClass("hidden");
}


function add_history(star) {
    history.push(star);
    console.log("history = " + history + "; " + star);
    draw_history();
}




function draw_history() {
    $('#history').empty();

    if( history.length > 0 ) {
        var last = history[history.length - 1];
        $('#history').append('<span id="hlink">⬅' + last.name + '</span>');
        $('span#hlink').click(
            function(e) {
                console.log("clicked");
                history = [];
                select_star(last, SPIN_TIME);
                draw_history();
            }
        );
    }
}



function highlight_partial(str) {
    d3.selectAll("circle")
	    .classed("cursor", function (d) {
	        if( d.name.substr(0, str.length) == str.toUpperCase() ) {
		        return 1;
	        } else {
		        return 0;
	        }
	});
}


function auto_complete_stars(text) {
    if( text.length ) {
	    highlight_partial(text);
    } else {
	    d3.selectAll("circle")
	        .classed("cursor", 0);
    }
}



function highlight_constellation(constellation) {
    console.log("Highlight " + constellation);
    d3.selectAll("circle")
        .each(function (d) {

            if( d.constellation == constellation ) {
                console.log(this.id + " show");
                $('#' + this.id).removeClass('hidden');
            } else {
                console.log(this.id + " hide");
                $('#' + this.id).addClass('hidden');
            } 
        }
             );
}




function render_map(elt, w, h, gostar) {
    
    width = w;
    height = h;
    
    cx = width * 0.5;
    cy = height * 0.5;
    R = cx * RFACTOR;
    
    var svg = d3.select(elt).append("svg:svg")
        .attr("width", width)
	    .attr("height", height);
    
    nodes = svg.selectAll("g")
    	.data(stars)
    	.enter()
    	.append("g")
    	.attr("transform",
    	      function(d) {
    		      return projection_isometric(d, [0, 0])
    	      });
    
    nodes.append("circle")
    	.attr("r", magnitude_f)
    	.attr("class", function(d) { return "star " + d.class } )
        .attr("id", function(d, i) { return "circle_" + i })
    	.style("opacity", star_opacity)
    	.on("click", function(d) {
    	    if( !stars_moving && d.z > -STAR_THRESHOLD ) {
    		    select_star(d, SPIN_TIME);
    		    d3.event.stopPropagation();
    	    }
    	});
    
    svg.append("circle")
        .attr("cx", cx).attr("cy", cy).attr("r", CURSOR_RADIUS)
        .attr("class", "pointer");

    svg.append("line")
        .attr("x1", cx + CURSOR_XY)
        .attr("y1", cy - CURSOR_XY)
        .attr("x2", width).attr("y2", 40)
        .attr("class", "pointer");
    
    nodes.append("title").text(function(d) { return d.name });
    
    
    
    if( gostar ) {
        var star = false;
        if( /^\d+$/.exec(gostar) ) {
            star = stars[gostar]
        } else {
            star = find_star(gostar.toUpperCase());
        }
        if( star ) {
            select_star(star, 0);
        }
    }


}




