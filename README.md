The CATALOGUS STELLARUM is a writing project which I posted on my twitter account @FSVO in 2012: I collected
every star with a proper name (Antares, Betelgeuse etc) from a couple of different sources, and then provided
a strange or amusing precis of each, in alphabetical order.

The code here is a rough draft of a nice web visualisation of the list.  I pulled the archive of FSVO tweets
from my Pinboard account, and then wrote a script to go through the list of stars and do Wikipedia searches
to get the astronomical coordinates, apparent magnitude and stellar category (colour) for each star.

Then I used the excellent d3 Javascript visualisation toolkit to render the stars in a stylised celestial
sphere.

TODO - 

Clean up a bunch of stars for which the Wikipedia search didn't get results.

Make the catalogue searchable.

Right now the sphere can be swivelled by clicking on a star - it wound be nicer if the sphere could
be spun by dragging any point on it as well.

The presentation of the star's tweet is not great.
