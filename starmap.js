
var width, height, cx, cy, R;

var nodes;

var star_angles = {};

var ra = 0;
var dec = 0;

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


function projection_isometric(d, ra, dec) {
    var rvect = rotate3([ d.vector.x, d.vector.y, d.vector.z ], ra, dec);
    x = cx + R * rvect[1];
    y = cy + R * rvect[2];
    z = R * rvect[0];
    d.x = x;
    d.y = y;
    d.z = z;
    return "translate(" + x + "," + y + ")";
}


function magnitude_f(d) {
    var size = 10 / Math.sqrt(1 + d.magnitude);
    if ( size < 1 ) {
	size = 1;
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
	    console.log("Matched " + sname);
	    return stars[i];
	}
    }
}

function select_star(star) {
    console.log("Select: " + star.name);
    nodes.transition()
	.duration(1000)
	.attr("transform", function(d) {
	    return projection_isometric(d, -star.ra, -star.dec)
	})
    
}

function select_star_tween(star) {
    console.log("Select: " + star.name);
    ra_interp = d3.interpolate(ra, -star.ra);
    de_interp = d3.interpolate(dec, -star.dec);
    nodes.transition()
	.duration(1000)
	.attrTween("transform", function(d, i, a) {
	    return select_tween(d, ra_interp, de_interp)
	});
    ra = -star.ra;
    dec = -star.dec;
}

function select_tween(d, ra_interp, de_interp) {
    return function(t) {
	var tw = projection_isometric(d, ra_interp(t), de_interp(t))
	return tw;
    }
}



function render_map(elt, w, h) {

    width = w;
    height = h;

    cx = width * 0.5;
    cy = height * 0.5;
    R = cx;

    var svg = d3.select(elt).append("svg:svg")
                .attr("width", width)
	        .attr("height", height);

    nodes = svg.selectAll("g")
	.data(stars)
	.enter()
	.append("g")
	.attr("transform", function(d) { return projection_isometric(d, 0, 0) });


    nodes.append("circle")
	.attr("r", magnitude_f)
	.attr("class", function(d) { return d.class; })
	.on("click", function(d) {
	    select_star_tween(d);
	    d3.event.stopPropagation();
	});


    nodes.append("text")
    	.attr("text-anchor", "middle")
    	.attr("class", function(d) { return d.class; })
    	.attr("dx", 0)
    	.attr("dy", ".35em")
    	.text(function(d) { return d.name })
    	.on("click", function(d) {
    	    select_star_tween(d);
    	    d3.event.stopPropagation();
    	});



    nodes.append("title")
	.text(function(d) { return d.name });


    

}
