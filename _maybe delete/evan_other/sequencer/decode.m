function name = decode(a)
	
	if a == 1
		name = 'Up';
	elseif a == 2
		name = 'Down';
	elseif a == 3
		name = 'Right';
	elseif a == 4
		name = 'Left';
	elseif a == 5
		name = 'Expand';
	elseif a == 6
		name = 'Shrink';
	elseif a == 7
		name = 'No Change';
	elseif a == 0
		name = 'Past image bounds'
	elseif a == 8
		name = 'Background';
	end