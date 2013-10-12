
function test_render(elt, w, h) {

    width = w;
    height = h;

    cx = width * 0.5;
    cy = height * 0.5;
    R = cx * 0.8;

    var svg = d3.select(elt).append("svg:svg")
                .attr("width", width)
	        .attr("height", height);


    svg.append("circle")
    	.attr("id", "cursorcircle")
    	.attr("r", R)
     	.attr("cx", cx)
     	.attr("cy", cy)
    	.attr("class", "cursor");

}


