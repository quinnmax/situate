function value = Qlookup(move1,act1,iou1,move2,act2,iou2,cur_move)
	global Qtab
	key = strcat(num2str(move1),',',num2str(act1),',',num2str(iou1),',',...
		num2str(move2),',',num2str(act2),',',num2str(iou2),',',num2str(cur_move));
	value  = Qtab(key)


function [] = Qupdate(value,move1,act1,iou1,move2,act2,iou2,cur_move)
	global Qtab
	key = strcat(num2str(move1),',',num2str(act1),',',num2str(iou1),',',...
		num2str(move2),',',num2str(act2),',',num2str(iou2),',',num2str(cur_move));
	Qtab(key) = value;