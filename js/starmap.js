// Starmap display methods

var width, height, cx, cy, R;

var nodes;

var position = [ 0, 0 ];

var spinning = 0;
var highlighted_circle;

var SPIN_TIME = 600;

var STAR_THRESHOLD = 400;
var STAR_OPACITY = 1;

var RFACTOR = .9;

var CURSOR_RADIUS = 80;

var current_star = false;

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


function magnitude_f(d) {
    var size = 10 / Math.sqrt(1.5 + d.magnitude * .5);
    if ( size < 2 ) {
	    size = 2;
    }
    return size;
}


function centre_star(sname) {
    var star = find_star(sname.toUpperCase());
    if( star ) {
	nodes.attr("transform", function(d) {
	    return projection_isometric(d, -star.ra, -star.dec)
	})

    }

}

function find_star(sname) {
    for ( var i = 0; i < stars.length; i++ ) {
	
	    if( stars[i].name == sname ) {
	        return stars[i];
	    }
    }
}


function select_star(star, spin_time) {

    gc_interp = rad2deginterp(position, [ -star.ra, -star.dec ]);
    
    // var gc_dist = d3.geo.distance(position, [ -star.ra, -star.dec ]);
    var duration = 0;

    duration = spin_time;

    spinning = 1;
    current_star = star;
    
    nodes.transition()
	    .duration(duration)
	    .attrTween("transform", function(d, i, a) {
	        return select_tween(d, gc_interp)
	    });
    
    d3.selectAll("circle")
	    .transition()
	    .duration(duration)
	    .styleTween("opacity", function(d, i, a) {
	        return hide_tween(d, gc_interp)
	    })
	    .each("end", function(e) {
	        d3.select(this).each(function(d, i) {
		        if( d.id == star.id ) {
		            highlight_star_circle(this);
                    hide_star_text();
		            show_star_text(d);
		            spinning = 0;
		        }
	        });
	    });
    
    position = [ -star.ra, -star.dec ];
}

function rad2deginterp(a, b) {
    var interp = d3.geo.interpolate(
	    [ rad2deg(a[0]), rad2deg(a[1]) ],
	    [ rad2deg(b[0]), rad2deg(b[1]) ]
    );
    
    return function(t) {
	    var p = interp(t);
	    return [ deg2rad(p[0]), deg2rad(p[1]) ];
    }
}

function select_tween(d, gc_interp) {
    return function(t) {
	    return projection_isometric(d, gc_interp(t))
    }
}

function hide_tween(d, gc_interp) {
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


function highlight_star_circle(elt) {
    // d3.select(elt).attr("class", "cursor");
    d3.select(elt).classed("highlight", 1);
    highlighted_circle = elt;
    console.log("Highlighted " + elt.id);
}

function show_star_text(d) {
    $("div#text").removeClass("O B A F G K M C P W start");
    $("input#starname").removeClass("O B A F G K M C P W start");
    $("div#text").addClass(d.class);
    $("input#starname").addClass(d.class);
    $("div#text").removeClass("hidden");
    $("input#starname").val(d.name);
    $("div#stardesignation").text(d.designation);
    $("div#description").html(d.text);
/*    $("div#coords").html(d.coords);  */
    
    /* What I'm doing here: do an each-loop through all of the links,
       look up the star's circles, add a line from each link to 
       each star, and add the onclick events. 
       
       For now I'm leaving the lines out. */
    
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
    if( highlighted_circle ) {
	    d3.select(highlighted_circle).classed("highlight", 0);
    }
    $("div#text").addClass("hidden");
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

function next_star(evt) {
    if( evt.which == 32 ) {
        if ( current_star ) {
            var id = current_star.id;
            if( stars[id + 1] ) {
                select_star(stars[id + 1], SPIN_TIME);
            } else {
                select_star(stars[0], SPIN_TIME);
            }
        } else {
            select_star(stars[0], SPIN_TIME);
        }
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
    	.attr("class", function(d) { return d.class } )
        .attr("id", function(d, i) { return "circle_" + i })
    	.style("opacity", star_opacity)
    	.on("click", function(d) {
    	    if( !spinning && d.z > -STAR_THRESHOLD ) {
    		    select_star(d, SPIN_TIME);
    		    d3.event.stopPropagation();
    	    }
    	});
    
    
    
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




