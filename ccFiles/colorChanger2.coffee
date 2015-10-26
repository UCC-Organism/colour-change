#ColorChanger by Kristoffer Ørum
SunCalc = require('suncalc');
color = require("sc-color");
fs = require "fs"
#load data files
sequence = require('./sequence.json');
palette = require('./palette.json');
config = require('../client-config/source.json');
oldstage = -1
day = 0
nowDay = 0
thePalette =[]
stageTimes = []
colorArray = []
baseColorsArray = []
fades = []	
interArray = []
interval = null
nowTimes = new Date();
times = SunCalc.getTimes(new Date(), 55.930548, 12.313206);

getRandom = (min,max) -> 
  return Math.random() * (max - min) + min

# Changes the RGB/HEX temporarily to a HSL-Value, modifies that value
# and changes it back to RGB/HEX.
changeHue = (rgb, degree) ->
	hsl = rgbToHSL(rgb)
	hsl.h += degree
	if hsl.h > 360
		hsl.h -= 360
	else hsl.h += 360  if hsl.h < 0
	hslToRGB hsl

# exepcts a string and returns an object
rgbToHSL = (rgb) ->
	
	# strip the leading # if it's there
	rgb = rgb.replace(/^\s*#|\s*$/g, "")
	
	# convert 3 char codes --> 6, e.g. `E0F` --> `EE00FF`
	rgb = rgb.replace(/(.)/g, "$1$1")  if rgb.length is 3
	r = parseInt(rgb.substr(0, 2), 16) / 255
	g = parseInt(rgb.substr(2, 2), 16) / 255
	b = parseInt(rgb.substr(4, 2), 16) / 255
	cMax = Math.max(r, g, b)
	cMin = Math.min(r, g, b)
	delta = cMax - cMin
	l = (cMax + cMin) / 2
	h = 0
	s = 0
	if delta is 0
		h = 0
	else if cMax is r
		h = 60 * (((g - b) / delta) % 6)
	else if cMax is g
		h = 60 * (((b - r) / delta) + 2)
	else
		h = 60 * (((r - g) / delta) + 4)
	if delta is 0
		s = 0
	else
		s = (delta / (1 - Math.abs(2 * l - 1)))
	h: h
	s: s
	l: l

# expects an object and returns a string
hslToRGB = (hsl) ->
	h = hsl.h
	s = hsl.s
	l = hsl.l
	c = (1 - Math.abs(2 * l - 1)) * s
	x = c * (1 - Math.abs((h / 60) % 2 - 1))
	m = l - c / 2
	r = undefined
	g = undefined
	b = undefined
	if h < 60
		r = c
		g = x
		b = 0
	else if h < 120
		r = x
		g = c
		b = 0
	else if h < 180
		r = 0
		g = c
		b = x
	else if h < 240
		r = 0
		g = x
		b = c
	else if h < 300
		r = x
		g = 0
		b = c
	else
		r = c
		g = 0
		b = x
	r = normalize_rgb_value(r, m)
	g = normalize_rgb_value(g, m)
	b = normalize_rgb_value(b, m)
	rgbToHex r, g, b
normalize_rgb_value = (color, m) ->
	color = Math.floor((color + m) * 255)
	color = 0  if color < 0
	color
rgbToHex = (r, g, b) ->
	"#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)



init = ->
	oldstage = -1
	day = 0
	nowDay = 0
	thePalette =[]
	stageTimes = []
	colorArray = []
	fades = []	
	interArray = []
	interval = null
	nowTimes = new Date();
	times = SunCalc.getTimes(new Date(), 55.930548, 12.313206);
	logger("initialising")
	#display some loaded data
	logger("random seed "+sequence.sequence[0]+ " / hue"+ sequence.hue[0]+ " / hueShift"+ sequence.hueShift[0] );
	logger("sample palette data: "+palette.social);
	logger("sample config data: "+config.screens[0].client_id)
	start()
	#start main loop every 30000 ms is the final
	
saveFile = ->
	fs.writeFile "temp.json", JSON.stringify(config), (error) ->
  		console.error("Error writing file", error) if error
 	fs.rename "temp.json", "../client-config/user.json", (err) ->
 		return logger(err) if err

 	#fs.rename "temp.json", "www.json", (errors) ->
		#console.error("Error renaming file", errors) if errors


  	#fs.createReadStream('temp.json').pipe(fs.createWriteStream('user.json'));


start = ->
	nowDay = getDay()
	newTime()
	newColors()
	oldColours = -1;
	# new colour every 30000 ms
	progress = - getMidnight()  
	interval = setInterval(->
		d = new Date()

		timeProgress = d.getTime() - getMidnight() 
		colorProgress = Math.floor (timeProgress/30000)
		logger2 (timeProgress + "/86400000ms day:" + getDay() + "/365 color " + colorProgress + "/" + colorArray[1].length + " " + colorArray[1].length*30000  )
		# set new colours if there are still some left in the array 
		if colorProgress < colorArray[0].length
			#if we have a new colourprogress set colours and save
			if colorProgress > oldColours
				setColors(colorProgress)
				saveFile()
				oldColours = colorProgress
				logger ("new json file saved")
		##if  new date 
		if nowDay != getDay() 
			clearInterval(interval) 
			init()
		#check we are out of colours and gemerate new colours
		return
	, 300)
	#outputHtml()

outputHtml = ->
	HTMLOut = " "
	#logger colorArray
	for key, value of colorArray
		#HTMLOut = HTMLOut + " value:  " + value
		#logger key + " html " + value
		for one, two of value
			#HTMLOut = HTMLOut + one + '<font color="' + two + '"> - ' + two + ' </span>' + "<br> " 
			HTMLOut = HTMLOut + ' <font size="0.001px" color="' + two + '">&#9608</span>' 
			#<FONT COLOR="######">text text text text text</FONT>"&#9608;"
			#HTMLOut = HTMLOut + key + '<span COLOR="' + two + '"> - ' + one + ' </span>' + "<br> " 
		HTMLOut = HTMLOut +  '<br><hr><br>'
	fs.writeFile "ccFiles/test.html", HTMLOut, (error) ->
  		console.error("Error writing file", error) if error

newTime = ->
	#BUILDS ARRY OF TIMES TO INTERPOLATE COLOURS 
	timesOfDay = []
	# 0 	nadir	nadir (darkest moment of the night, sun is in the lowest position)
	timesOfDay.push times.nadir.getTime()
	# 1 	nightEnd	night ends (morning astronomical twilight starts)
	timesOfDay.push times.nightEnd.getTime()
	# 2 	nauticalDawn	nautical dawn (morning nautical twilight starts)
	timesOfDay.push times.nauticalDawn.getTime()
	# 3 	dawn
	timesOfDay.push times.dawn.getTime()
	# 4 	sunrise	sunrise (top edge of the sun appears on the horizon)
	timesOfDay.push times.sunrise.getTime()
	# 5 	sunriseEnd	sunrise ends (bottom edge of the sun touches the horizon)
	timesOfDay.push times.sunriseEnd.getTime()
	# 6 	goldenHourEnd	morning golden hour (soft light, best time for photography) ends
	timesOfDay.push times.goldenHourEnd.getTime()
	# 7 	solarNoon	solar noon (sun is in the highest position)
	timesOfDay.push times.solarNoon.getTime()
	# 8 	goldenHourevening golden hour starts
	timesOfDay.push times.goldenHour.getTime()
	# 9 	sunsetStart	sunset starts (bottom edge of the sun touches the horizon)
	timesOfDay.push times.sunsetStart.getTime()
	# 10 	sunset	sunset (sun disappears below the horizon, evening civil twilight starts)
	timesOfDay.push times.sunset.getTime()
	# 11 	Dusk (evening nautical twilight starts)
	timesOfDay.push times.dusk.getTime()
	# 12	nauticalDusk	nautical dusk (evening astronomical twilight starts)
	timesOfDay.push times.nauticalDusk.getTime()
	# 13 night	night starts (dark enough for astronomical observations)
	timesOfDay.push times.night.getTime()
	#LIST TIMES 
	logger("Nadir "+ times.nadir.getHours() + ':' + times.nadir.getMinutes()+" night ends "+ times.nightEnd.getHours() + ':' + times.nightEnd.getMinutes()+"nauticalDawn "+ times.nauticalDawn.getHours() + ':' + times.nauticalDawn.getMinutes()+" dawn "+ times.dawn.getHours() + ':' + times.dawn.getMinutes()+" sunrise "+ times.sunrise.getHours() + ':' + times.sunrise.getMinutes()+" sunriseEnd "+ times.sunriseEnd.getHours() + ':' + times.sunriseEnd.getMinutes()+" goldenHourEnd "+ times.goldenHourEnd.getHours() + ':' + times.goldenHourEnd.getMinutes()+" solarNoon "+ times.solarNoon.getHours() + ':' + times.solarNoon.getMinutes()+"goldenHour "+ times.goldenHour.getHours() + ':' + times.goldenHour.getMinutes()+" sunsetStart "+ times.sunsetStart.getHours() + ':' + times.sunsetStart.getMinutes()+" sunset "+ times.sunset.getHours() + ':' + times.sunset.getMinutes()+" dusk "+ times.dusk.getHours() + ':' + times.dusk.getMinutes()+" nauticalDusk "+ times.nauticalDusk.getHours() + ':' + times.nauticalDusk.getMinutes()+" night "+ times.night.getHours() + ':' + times.night.getMinutes())


getDay = () ->
	start = new Date(nowTimes.getFullYear(), 0, 0);
	diff = nowTimes - start;
	oneDay = 1000 * 60 * 60 * 24;
	day = Math.floor(diff / oneDay);

baseColors = () ->
	#clear color array just in case
	baseColorsArray = []
	
	#define basic 
	#colour hue steps 
	svalue = 27.6923076923
	s = 0
	shift = shift + 27.6923076923
	#define 13 basic colours for each agent
	
	col1 = color('hsv', s, 100, 100);
	s = s + svalue
	col2 = color('hsv', s, 100, 100);
	s = s + svalue
	col3 = color('hsv', s, 100, 100);
	s = s + svalue
	col4 = color('hsv', s, 100, 100);
	s = s + svalue
	col5 = color('hsv', s, 100, 100);
	s = s + svalue
	col6 = color('hsv', s, 100, 100);
	s = s + svalue
	col7 = color('hsv', s, 100, 100);
	s = s + svalue
	col8 = color('hsv', s, 100, 100);
	s = s + svalue
	col9 = color('hsv', s, 100, 100);
	s = s + svalue
	col10 = color('hsv', s, 100, 100);
	s = s + svalue
	col11 = color('hsv', s, 100, 100);
	s = s + svalue
	col12 = color('hsv', s, 100, 100);
	s = s + svalue
	col13 = color('hsv', s, 100, 100);

	socialCol = color('hsv', s, 100, 100);
	knowledgeCol = color('hsv', 120, 100, 100)
	powerCol = color('hsv', 240, 100, 100)
	backgroundCol =  color("#3a5528").hue("+" + getRandom(0,360) )
	logger getRandom(0,360)

	# 	Social      green       #00FF7D
	baseColorsArray.push socialCol
 	#   knowledge   orange      #FFBF00
	baseColorsArray.push knowledgeCol
 	#   power       pink        #FF00E0
	baseColorsArray.push powerCol
 	#   dirt        darkgrey    #dddddd
	baseColorsArray.push color('hsv', 0, 0, 20);
	
# AGENTS two values
	 #    Spl         rød     #d64546
	baseColorsArray.push col1.tone(.4);
	baseColorsArray.push col1.tint(.4);
	#logger ("spl1: " + col1.tone(.5).hex6())	
	#logger ("spl1: " + col1.tint(.4).hex6())
	 #    Pmu         orange  #ea9e4e
	baseColorsArray.push col2.tone(.4);
	baseColorsArray.push col2.tint(.4);
	 #    fys         gul     #e9d252
	baseColorsArray.push col3.tone(.4);
	baseColorsArray.push col3.tint(.4)
	 #    soc         blå     #3e639f
	baseColorsArray.push col4.tone(.4);
	baseColorsArray.push col4.tint(.4)
	 #    paed        grøn    #3ea045
	baseColorsArray.push col5.tone(.4);
	baseColorsArray.push col5.tint(.4)
	 #    div
	baseColorsArray.push col6.tone(.4);
	baseColorsArray.push col6.tint(.4)
	 #    diplomS
	baseColorsArray.push col7.tone(.4);
	baseColorsArray.push col7.tint(.4)
	 #    diplomL
	baseColorsArray.push col8.tone(.4)
	baseColorsArray.push col8.tint(.4)
	 #    teacher     
	baseColorsArray.push col9.tone(.4);
	baseColorsArray.push col9.tint(.4)
	 #    researcher
	baseColorsArray.push col10.tone(.4);
	baseColorsArray.push col10.tint(.4)
	 #    janitor
	baseColorsArray.push col11.tone(.4);
	baseColorsArray.push col11.tint(.4)
	# cook
	baseColorsArray.push col12.tone(.4);
	baseColorsArray.push col12.tint(.4)
	 #    admin       lilla ;
	baseColorsArray.push col13.tone(.4);
	baseColorsArray.push col13.tint(.4)
	 #    unknown
	baseColorsArray.push col11.tone(.4);
	baseColorsArray.push col11.tint(.4);
	
# ROOMS
	#     other
	baseColorsArray.push backgroundCol.tint(.2); 
	baseColorsArray.push backgroundCol.tint(.6); 
	baseColorsArray.push backgroundCol.tint(.8); 
	#     classroom
	baseColorsArray.push backgroundCol.tint(.2); 
	baseColorsArray.push backgroundCol.tint(.6); 
	baseColorsArray.push backgroundCol.tint(.8); 
	#     toilet
	baseColorsArray.push backgroundCol.complement().tone(.2); 
	baseColorsArray.push backgroundCol.complement().tone(.6); 
	baseColorsArray.push backgroundCol.complement().tone(.8); 
	#     research
	baseColorsArray.push knowledgeCol.tone(.2);
	baseColorsArray.push knowledgeCol.tone(.6);
	baseColorsArray.push knowledgeCol.tone(.8);
	#     knowledge
	baseColorsArray.push knowledgeCol.shade(.2);
	baseColorsArray.push knowledgeCol.shade(.6);
	baseColorsArray.push knowledgeCol.shade(.8);
	#     teacher
	baseColorsArray.push knowledgeCol.tint(.2);
	baseColorsArray.push knowledgeCol.tint(.6);
	baseColorsArray.push knowledgeCol.tint(.8);
	#     admin
	baseColorsArray.push powerCol.shade(.2);
	baseColorsArray.push powerCol.shade(.6);
	baseColorsArray.push powerCol.shade(.8);
	#     closet
	baseColorsArray.push col11.tone(.2); 
	baseColorsArray.push col11.tone(.6); 
	baseColorsArray.push col11.tone(.8); 
	#     food
	baseColorsArray.push socialCol.shade(.2);
	baseColorsArray.push socialCol.shade(.6);
	baseColorsArray.push socialCol.shade(.8);
	#     exit
	baseColorsArray.push backgroundCol.tone(.2); 
	baseColorsArray.push backgroundCol.tone(.6); 
	baseColorsArray.push backgroundCol.tone(.8); 
	#     empty
	baseColorsArray.push backgroundCol.shade(.1); 
	baseColorsArray.push backgroundCol.shade(.2); 
	baseColorsArray.push backgroundCol.shade(.4); 
	#    cell	
	baseColorsArray.push backgroundCol.tint(.2);
	baseColorsArray.push backgroundCol.tint(.3);
	baseColorsArray.push backgroundCol.tint(.4);
	
#BLOBS
	#socialBlob
	baseColorsArray.push socialCol.shade(.2).blend(backgroundCol,.5);
	baseColorsArray.push socialCol.shade(.6);
	baseColorsArray.push socialCol.shade(.8).blend(backgroundCol,.5);
    #knowledgeBlob
	baseColorsArray.push knowledgeCol.shade(.2).blend(backgroundCol,.5);
	baseColorsArray.push knowledgeCol.shade(.6);
	baseColorsArray.push knowledgeCol.shade(.8).blend(backgroundCol,.5);
    #powerBlob
	baseColorsArray.push powerCol.shade(.2).blend(backgroundCol,.5);
	baseColorsArray.push powerCol.shade(.6)
	baseColorsArray.push powerCol.shade(.8).blend(backgroundCol,.5);

#OTHER
	#"bgColor": "#FFFFFF",
	baseColorsArray.push backgroundCol;
	# "membraneColor": "#DDDDDD",
	baseColorsArray.push backgroundCol.complement();	
	# "agentLineColor": "#000000",
	baseColorsArray.push backgroundCol.tint(.3); 
	# "agentFillColor": "#FFFFFF",
	baseColorsArray.push backgroundCol.tint(.9); 

	#agents mix with white and make a variation
	#baseColorsArray.push col1.tint(.2)
	#baseColorsArray.push col1.shade(.4)


	console.log palette[0]
	console.log  baseColorsArray[0]
	#console.log col1.hex6()," ",agenta1.hex6(),"  ",agenta2.hex6()

	#console.log "base colours",col1.hex6(),col2.hex6(),col3.hex6(),col4.hex6(),col5.hex6(),col6.hex6(),col7.hex6(),col8.hex6(),col9.hex6(),col10.hex6(),col11.hex6(),col12.hex6(),col13.hex6()


newColors = ()->
	#detiermine palette fra sequence
	getDay()

	currentPalette = sequence.sequence[day]
	#logger("palette "+currentPalette+" and "+currentHue+" on this day of the year "+day)
	thePalette =[]
	fades =[]
	#determine hour cycle
	shifts = parseInt(sequence.hueShift[day]) + parseInt(sequence.hue[day])
	#logger ("the hue shifts "+ shifts ) 
	currentStage = checktime();
	oldstage = currentStage;
	baseColors()
	#define mix colours
	nightColour = color('#0000ff') 
	dawnColour = color('#ff00ff')
	orange = color('#ff5500')
	yellow = color('#ffff00')
	
	#USE MULTIPLY TO MAKE NIGHT
	for key,value of baseColorsArray
		#logger key + " loading colors  " + value[currentPalette]
		#0
		#nadir  = color(value[currentPalette]).hue('+'+shifts).blend(nightColour, .5).hex6()
		shifts = parseInt(sequence.hueShift[day])
		night = color(value).hue('+'+shifts).blend(nightColour, .2).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#night = color(value[currentPalette]).hue('+'+shifts).blend(nightColour, .2).hex6()
		nadir = color(value).hue('+'+shifts).blend(nightColour, .2).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#nadir = color(value[currentPalette]).hue('+'+shifts).blend(nightColour, .2).hex6()
		#nadir = changeHue(value[currentPalette],shifts)
		#1 nightEnd = color(two).hue(currentHue+(shifts*2)).saturation(20).hex6()
		nightEnd = color(value).hue('+'+shifts).blend(dawnColour, .2).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#nightEnd = changeHue(value[currentPalette],shifts)
		#2 nauticalDawn =  color(two).hue(currentHue+(shifts*3)).saturation(30).hex6()
		nauticalDawn = color(value).hue('+'+shifts).blend(dawnColour, .2).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#nauticalDawn = changeHue(value[currentPalette],shifts)
		#3 dawn = color(two).hue(currentHue+(shifts*4)).saturation(40).hex6()
		dawn = color(value).hue('+'+shifts).blend(orange, .3).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#dawn = changeHue(value[currentPalette],shifts)
		#4 sunrise = color(two).hue(currentHue+(shifts*5)).saturation(50).hex6()
		sunrise = color(value).hue('+'+shifts).blend(yellow, .2).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#sunrise = changeHue(value[currentPalette],shifts)
		#5 sunriseEnd = color(two).hue(currentHue+(shifts*6)).saturation(80).hex6()
		sunriseEnd = color(value).hue('+'+shifts).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#sunriseEnd = changeHue(value[currentPalette],shifts)
		#6 goldenHourEnd = color(two).hue(currentHue+(shifts*7)).hex6()
		goldenHourEnd = color(value).hue('+'+shifts).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#goldenHourEnd = changeHue(value[currentPalette],shifts)
		#7 solarNoon = color(two).hue(currentHue+(shifts*8)).hex6()
		solarNoon = color(value).hue('+'+shifts).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#solarNoon  = changeHue(value[currentPalette],shifts)
		#8 goldenHour = color(two).hue(currentHue+(shifts*9)).saturation(80).hex6()
		goldenHour = color(value).hue('+'+shifts).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#goldenHour = changeHue(value[currentPalette],shifts)
		#9sunsetStart = color(two).hue(currentHue+(shifts*10)).saturation(50).hex6()
		sunsetStart = color(value).hue('+'+shifts).blend(yellow, .2).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#sunsetStart = changeHue(value[currentPalette],shifts)
		#10 sunset = color(two).hue(currentHue+(shifts*11)).saturation(40).hex6()
		sunset = color(value).hue('+'+shifts).blend(orange, .3).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#sunset  = changeHue(value[currentPalette],shifts)
		#11 dusk = color(two).hue(currentHue+(shifts*12)).saturation(30).hex6()
		dusk = color(value).hue('+'+shifts).mul(orange, .3).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#dusk = changeHue(value[currentPalette],shifts)
		#12 nauticalDusk = color(two).hue(currentHue+(shifts*13)).saturation(20).hex6()
		nauticalDusk = color(value).hue('+'+shifts).blend(nightColour, .3).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#nauticalDusk =  changeHue(value[currentPalette],shifts)
		#13 night = color(two).hue(currentHue+(shifts*14)).saturation(10).hex6()
		#night = color(value[currentPalette]).hue('+'+shifts).blend(nightColour, .5).hex6()
		night2 = color(value).hue('+'+shifts).blend(nightColour, .3).hex6()
		shifts = parseInt(shifts) + parseInt(sequence.hueShift[day])
		#store all the colours in fades array
		#NIGHT IS PUSHED TWICE TO AVOID UNDEFINED COLOR
		console.log key + " : " + night + nadir + nightEnd + nauticalDawn + dawn + sunrise + sunriseEnd + goldenHourEnd + solarNoon + goldenHour + sunsetStart + sunset + dusk + nauticalDusk + night + nadir
		fades.push [night,nadir,nightEnd,nauticalDawn,dawn,sunrise,sunriseEnd,goldenHourEnd,solarNoon,goldenHour,sunsetStart,sunset,dusk,nauticalDusk,night2,nadir]
		
		#thePalette.push tenpArray[currentStage]
	populateColourArray()




populateColourArray = ->

	getTimes()
	#30000 increments for 30 second intervals 
	#MAKE THIS PROCEDURAL
	#this is how many steps between stage one and two
	#loop though all each fade value 
	logger ("# of values to fades "+fades.length)
	logger ("number of fade stages stageTimes " + stageTimes.length)

	colorArray = []
	l = 0
	#while l < 1 
	while l < fades.length
		#loops value to be faded 
		#logger l  + " " + fades[l]
		i = 0;
		#EMPTY ARRAY OF VALUES
		interArray = []
		interpolationsOverflow = 0
		#while i < 2
		while i < stageTimes.length - 1
			#loops through stages 
			interpolations = Math.floor((stageTimes[i+1]-stageTimes[i])/30000)
			#logger " stage  " + i + " has " + interpolations + " interpolations from " + fades[l][i] + " to " + fades[l][i+1]	
			#interpolationsFloat = (stageTimes[i+1]-stageTimes[i])/30000
			#correct Math.floor inaccuracy 
			#interpolationsOverflow = interpolationsOverflow + (interpolationsFloat - interpolations)
			#logger interpolationsOverflow
			#if interpolationsOverflow > 1
				#interpolations = interpolations + Math.floor(interpolationsOverflow)
				#interpolationsOverflow = interpolationsOverflow - Math.floor(interpolationsOverflow)
				#logger interpolationsOverflow + " left over fractions added";
			#calculates number of interpolations for current stage
			#logger "stage " + i
			#interArray fades[i][i]
			ii = 0
			while ii < interpolations 

				#get colour from pressent stage
				second = fades[l][i]
				#get colour from next stage 
				first = fades[l][i+1]	
				#push interpolation
				#logger "fades" + l + "stage " + i + " color 1 " + first + "color 2 "+ second + " inter " + interpolations + "/" + ii
				#logger interpolateColor(second, first, interpolations, ii)
				interArray.push [interpolateColor(second,first, interpolations, ii)]
				#logger (first + " " + second )
				
				ii++
			i++
		#logger ("value being faded "+l)	
		colorArray.push interArray 
		l++
		#logger (86400000 - (colorArray[0].length * 30000) + " missing MS & " + (86400000 - (colorArray[0].length * 30000))/30000 + " missing interpolations")
	#display first interpolation array	
	logger "number of colors interpolated "+ colorArray[0].length

#TIME RELATED
		
getTimes = ->
	stageTimes = []
	logger(getMidnight()+ " - midnight");
	stageTimes.push getMidnight()
	logger (times.nadir.getTime() + " - nadir       -  0")
	stageTimes.push times.nadir.getTime()
	logger (times.nightEnd.getTime() + " - nightEnd - " +  (times.nightEnd.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.nightEnd.getTime()
	logger (times.nauticalDawn.getTime() + " - nauticalDawn  - " +  (times.nauticalDawn.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.nauticalDawn.getTime()
	logger (times.dawn.getTime() + " - dawn  - " +  (times.dawn.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.dawn.getTime()
	logger (times.sunrise.getTime() + " - sunrise - " +  (times.sunrise.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.sunrise.getTime()
	logger (times.sunriseEnd.getTime() + " - sunriseEnd - " +  (times.sunriseEnd.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.sunriseEnd.getTime()
	logger (times.goldenHourEnd.getTime() + " - goldenHourEnd - " +  (times.goldenHourEnd.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.goldenHourEnd.getTime()
	logger (times.solarNoon.getTime() + " - solarNoon - " +  (times.solarNoon.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.solarNoon.getTime()
	logger (times.goldenHour.getTime() + " - goldenHour - " +  (times.goldenHour.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.goldenHour.getTime()
	logger (times.sunsetStart.getTime() + " - sunsetStart  - " +  (times.sunsetStart.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.sunsetStart.getTime()
	logger (times.sunset.getTime() + " - sunset  - " +  (times.sunset.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.sunset.getTime()
	logger (times.dusk.getTime() + " - dusk  - " +  (times.dusk.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.dusk.getTime() 
	logger (times.nauticalDusk.getTime() + " - nauticalDusk  - " +  (times.nauticalDusk.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.nauticalDusk.getTime()
	logger (times.night.getTime() + " - night  - " +  (times.night.getTime() - getMidnight()) / 3000 )
	stageTimes.push times.night.getTime() 
	logger (getNextMidnight()+ " - midnight  - " +  (getNextMidnight() - getMidnight()) / 3000 )
	stageTimes.push getNextMidnight()
	#total = 86400000 
	#total2 = stageTimes[15] - stageTimes[0]
	#logger "missing " + total + " / " + total2
	#logger getNextMidnight() - getMidnight()


getMidnight = ->
	d = new Date();
	d.setHours(0,0,0,0);
	return +d

getNextMidnight = ->
	d = new Date();
	d.setDate(d.getDate() + 1);
	d.setHours(0,0,0,0);
	return +d

getMsSinceMidnight = (d) ->
	e = new Date(d);
	return d - e.setHours(0,0,0,0);


setColors = (num) ->
	#set all colours in jsomn string
	#logger colorArray[0][num]
	config.energyTypes.social.color = colorArray[0][num][0]
	config.energyTypes.knowledge.color = colorArray[1][num][0]
	config.energyTypes.power.color = colorArray[2][num][0]
	config.energyTypes.dirt.color = colorArray[3][num][0]

	config.agentTypes.spl.colors[0] = colorArray[4][num][0]
	config.agentTypes.spl.colors[1] = colorArray[5][num][0]

	config.agentTypes.pmu.colors[0] = colorArray[6][num][0]
	config.agentTypes.pmu.colors[1] = colorArray[7][num][0]

	config.agentTypes.fys.colors[0] = colorArray[8][num][0]
	config.agentTypes.fys.colors[1] = colorArray[9][num][0]
	
	config.agentTypes.soc.colors[0] = colorArray[10][num][0]
	config.agentTypes.soc.colors[1] = colorArray[11][num][0]
	
	config.agentTypes.paed.colors[0] = colorArray[12][num][0]
	config.agentTypes.paed.colors[1] = colorArray[13][num][0]
	
	config.agentTypes.div.colors[0] = colorArray[14][num][0]
	config.agentTypes.div.colors[1] = colorArray[15][num][0]
	
	config.agentTypes.diplomS.colors[0] = colorArray[16][num][0]
	config.agentTypes.diplomS.colors[1] = colorArray[17][num][0]
	
	config.agentTypes.diplomL.colors[0] = colorArray[18][num][0]
	config.agentTypes.diplomL.colors[1] = colorArray[19][num][0]
	
	config.agentTypes.teacher.colors[0] = colorArray[20][num][0]
	config.agentTypes.teacher.colors[1] = colorArray[21][num][0]
	
	config.agentTypes.researcher.colors[0] = colorArray[22][num][0]
	config.agentTypes.researcher.colors[1] = colorArray[23][num][0]
	
	config.agentTypes.janitor.colors[0] = colorArray[24][num][0]
	config.agentTypes.janitor.colors[1] = colorArray[25][num][0]
	
	config.agentTypes.cook.colors[0] = colorArray[26][num][0]
	config.agentTypes.cook.colors[1] = colorArray[27][num][0]
	
	config.agentTypes.admin.colors[0] = colorArray[28][num][0]
	config.agentTypes.admin.colors[1] = colorArray[29][num][0]
	
	config.agentTypes.unknown.colors[0] = colorArray[30][num][0]
	config.agentTypes.unknown.colors[1] = colorArray[31][num][0]



	config.roomTypes.other.color = colorArray[32][num][0]
	config.roomTypes.other.centerColor = colorArray[33][num][0]
	config.roomTypes.other.edgeColor = colorArray[34][num][0]

	config.roomTypes.classroom.color = colorArray[35][num][0]
	config.roomTypes.classroom.centerColor = colorArray[36][num][0]
	config.roomTypes.classroom.edgeColor = colorArray[37][num][0]
	
	config.roomTypes.toilet.color = colorArray[38][num][0]
	config.roomTypes.toilet.centerColor = colorArray[39][num][0]
	config.roomTypes.toilet.edgeColor = colorArray[40][num][0]

	config.roomTypes.research.color = colorArray[41][num][0]
	config.roomTypes.research.centerColor = colorArray[42][num][0]
	config.roomTypes.research.edgeColor = colorArray[43][num][0]

	config.roomTypes.knowledge.color = colorArray[44][num][0]
	config.roomTypes.knowledge.centerColor = colorArray[45][num][0]
	config.roomTypes.knowledge.edgeColor = colorArray[46][num][0]

	config.roomTypes.teacher.color = colorArray[47][num][0]
	config.roomTypes.teacher.centerColor = colorArray[48][num][0]
	config.roomTypes.teacher.edgeColor = colorArray[49][num][0]

	config.roomTypes.admin.color = colorArray[50][num][0]
	config.roomTypes.admin.centerColor = colorArray[51][num][0]
	config.roomTypes.admin.edgeColor = colorArray[52][num][0]

	config.roomTypes.closet.color = colorArray[53][num][0]
	config.roomTypes.closet.centerColor = colorArray[54][num][0]
	config.roomTypes.closet.edgeColor = colorArray[55][num][0]
	
	config.roomTypes.food.color = colorArray[56][num][0]
	config.roomTypes.food.centerColor = colorArray[57][num][0]
	config.roomTypes.food.edgeColor = colorArray[58][num][0]

	config.roomTypes.exit.color = colorArray[59][num][0]
	config.roomTypes.exit.centerColor = colorArray[60][num][0]
	config.roomTypes.exit.edgeColor = colorArray[61][num][0]

	config.roomTypes.empty.color = colorArray[62][num][0]
	config.roomTypes.empty.centerColor = colorArray[63][num][0]
	config.roomTypes.empty.edgeColor = colorArray[64][num][0]
	
	config.roomTypes.cell.color = colorArray[65][num][0]
	config.roomTypes.cell.centerColor = colorArray[66][num][0]
	config.roomTypes.cell.edgeColor = colorArray[67][num][0]

	config.roomTypes.socialBlob.color = colorArray[68][num][0]
	config.roomTypes.socialBlob.centerColor = colorArray[69][num][0]
	config.roomTypes.socialBlob.edgeColor = colorArray[70][num][0]
	
	config.roomTypes.knowledgeBlob.color = colorArray[71][num][0]
	config.roomTypes.knowledgeBlob.centerColor = colorArray[72][num][0]
	config.roomTypes.knowledgeBlob.edgeColor = colorArray[73][num][0]
	
	config.roomTypes.powerBlob.color = colorArray[74][num][0]
	config.roomTypes.powerBlob.centerColor = colorArray[75][num][0]
	config.roomTypes.powerBlob.edgeColor = colorArray[76][num][0]
	
	config.bgColor = colorArray[77][num][0]
	config.membraneColor = colorArray[78][num][0]
	config.agentLineColor = colorArray[79][num][0]
	config.agentFillColor = colorArray[80][num][0]



checktime =  -> 
	stage = 0;
	# 0 Nadir
	if nowTimes.getTime() > times.nadir.getTime()
		stage = 0;
	if nowTimes.getTime() > times.nightEnd.getTime()
		stage = 1;
	if nowTimes.getTime() > times.nauticalDawn.getTime()
		stage = 2;
	if nowTimes.getTime() > times.dawn.getTime()
		stage = 3;
	if nowTimes.getTime() > times.sunrise.getTime()
		stage = 4;
	if nowTimes.getTime() > times.sunriseEnd.getTime()
		stage = 5;
	if nowTimes.getTime() > times.goldenHourEnd.getTime()
		stage = 6;
	if nowTimes.getTime() > times.solarNoon.getTime()
		stage = 7;
	if nowTimes.getTime() > times.goldenHour.getTime()
		stage = 8;
	if nowTimes.getTime() > times.sunsetStart.getTime()
		stage = 9;
	if nowTimes.getTime() > times.sunset.getTime()
		stage = 10;
	if nowTimes.getTime() > times.dusk.getTime()
		stage = 11;
	if nowTimes.getTime() > times.nauticalDusk.getTime()
		stage = 12;
	if nowTimes.getTime() > times.night.getTime()
		stage = 13;
	return(stage)


logger = (x) -> 
	console.log ("KC: "+x )


logger2 = (x) -> 
	process.stdout.write ( " " + x + "\r")

interpolateColor = (minColor, maxColor, maxDepth, depth) ->
  d2h = (d) ->
    d.toString 16
  h2d = (h) ->
    parseInt h, 16
  return minColor  if depth is 0
  return maxColor  if depth is maxDepth
  color = "#"
  i = 1

  while i <= 6
    minVal = new Number(h2d(minColor.substr(i, 2)))
    maxVal = new Number(h2d(maxColor.substr(i, 2)))
    nVal = minVal + (maxVal - minVal) * (depth / maxDepth)
    val = d2h(Math.floor(nVal))
    val = "0" + val  while val.length < 2
    color += val
    i += 2
  color



##startup functions
init()


##FUNCTION NOT IN USE
	#checkData()
	#console.log colorArray.length
	#logger ("This is the palette: "+colorArray)


checkData = ->
	logger("**stuff**")
	i= 0
	logger(config.energyTypes.social.color);
	logger(config.energyTypes.knowledge.color);
	logger(config.energyTypes.power.color);
	logger(config.energyTypes.dirt.color);

	logger(config.agentTypes.spl.colors[0])
	logger(config.agentTypes.spl.colors[1])

	logger(config.agentTypes.pmu.colors[0])
	logger(config.agentTypes.pmu.colors[1])

	logger(config.agentTypes.fys.colors[0])
	logger(config.agentTypes.fys.colors[1])

	logger(config.agentTypes.soc.colors[0])
	logger(config.agentTypes.soc.colors[1])

	logger(config.agentTypes.paed.colors[0])
	logger(config.agentTypes.paed.colors[1])

	logger(config.agentTypes.div.colors[0])
	logger(config.agentTypes.div.colors[1])

	logger(config.agentTypes.diplomS.colors[0])
	logger(config.agentTypes.diplomS.colors[1])

	logger(config.agentTypes.diplomL.colors[0])
	logger(config.agentTypes.diplomL.colors[1])

	logger(config.agentTypes.teacher.colors[0])
	logger(config.agentTypes.teacher.colors[1])

	logger(config.agentTypes.researcher.colors[0])
	logger(config.agentTypes.researcher.colors[1])

	logger(config.agentTypes.janitor.colors[0])
	logger(config.agentTypes.janitor.colors[1])

	logger(config.agentTypes.cook.colors[0])
	logger(config.agentTypes.cook.colors[1])
	
	logger(config.agentTypes.admin.colors[0])
	logger(config.agentTypes.admin.colors[1])
	
	logger(config.agentTypes.unknown.colors[0])
	logger(config.agentTypes.unknown.colors[1])
	
	logger(config.roomTypes.other.color)
	logger(config.roomTypes.other.centerColor)	
	logger(config.roomTypes.other.centerColor)
	
	logger(config.roomTypes.classroom.color)
	logger(config.roomTypes.classroom.centerColor)	
	logger(config.roomTypes.classroom.centerColor)

	logger(config.roomTypes.toilet.color)
	logger(config.roomTypes.toilet.centerColor)	
	logger(config.roomTypes.toilet.centerColor)
	
	logger(config.roomTypes.research.color)
	logger(config.roomTypes.research.centerColor)	
	logger(config.roomTypes.research.centerColor)
	
	logger(config.roomTypes.knowledge.color)
	logger(config.roomTypes.knowledge.centerColor)	
	logger(config.roomTypes.knowledge.centerColor)
	
	logger(config.roomTypes.teacher.color)
	logger(config.roomTypes.teacher.centerColor)	
	logger(config.roomTypes.teacher.centerColor)
	
	logger(config.roomTypes.admin.color)
	logger(config.roomTypes.admin.centerColor)	
	logger(config.roomTypes.admin.centerColor)
	
	logger(config.roomTypes.closet.color)
	logger(config.roomTypes.closet.centerColor)	
	logger(config.roomTypes.closet.centerColor)
	
	logger(config.roomTypes.food.color)
	logger(config.roomTypes.food.centerColor)	
	logger(config.roomTypes.food.centerColor)
	
	logger(config.roomTypes.exit.color)
	logger(config.roomTypes.exit.centerColor)	
	logger(config.roomTypes.exit.centerColor)
	
	logger(config.roomTypes.empty.color)
	logger(config.roomTypes.empty.centerColor)	
	logger(config.roomTypes.empty.centerColor)
	
	logger(config.roomTypes.cell.color)
	logger(config.roomTypes.cell.centerColor)	
	logger(config.roomTypes.cell.centerColor)
	
	logger(config.roomTypes.socialBlob.color)
	logger(config.roomTypes.socialBlob.centerColor)	
	logger(config.roomTypes.socialBlob.centerColor)
	
	logger(config.roomTypes.knowledgeBlob.color)
	logger(config.roomTypes.knowledgeBlob.centerColor)	
	logger(config.roomTypes.knowledgeBlob.centerColor)
	
	logger(config.roomTypes.powerBlob.color)
	logger(config.roomTypes.powerBlob.centerColor)	
	logger(config.roomTypes.powerBlob.centerColor)
	
	logger(config.bgColor)
	logger(config.membraneColor)

	logger(config.agentLineColor)
	logger(config.agentFillColor)




