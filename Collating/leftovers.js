    var dragx = 0;
    var dragy = 0;

    var drag = d3.behavior.drag()
        .origin(Object)
        .on("drag", function(d) {
    	    var xoff = d3.event.x;
    	    console.log("X offset " + xoff);
    	    console.log("Origin " + d.x + " RA = " + d.ra);
    	    if( xoff >= -R && xoff <= R ) {
    		ra = Math.acos(xoff / R);
    		nodes.attr("transform", projection_isometric)
    	    }
    	});
