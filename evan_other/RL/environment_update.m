function [class_guess,IOU,new_crop] = environment_update(base,object,ground,crop,shift)
	global dog_svm_model walker_svm_model leash_svm_model;
	start_crop = imcrop(base,crop)
	if strcmp(object,'dog') == 1
		model = dog_svm_model;
	elseif strcmp(object,'walker') == 1
		model = walker_svm_model;
	elseif strcmp(object,'leash') == 1
		model = leash_svm_model;
	else
		disp('no matching model');
	end 	
	r4 = [1,1,1,1];
	fli = 0;
	r3 = [shift,shift,shift,shift];
	new_w = 0; new_h = 0;
	x2 = crop(1); y2 = crop(2); w2 = crop(3); h2 = crop(4);
	bnew_w = w2*(1+shift);
	bnew_h = h2*(1+shift);
	snew_w = w2*(1-shift);
	snew_h = h2*(1-shift);

	class_guess = predict_crop(model,start_crop);
    if class_guess == 0;
        break
    elseif class_guess == 1
        crop = up(x2,y2,w2,h2,r3,r4,fli,new_w,new_h);
    elseif class_guess == 2
        crop = down(x2,y2,w2,h2,r3,r4,fli,new_w,new_h);
    elseif class_guess == 3
        crop = right(x2,y2,w2,h2,r3,r4,fli,new_w,new_h);
    elseif class_guess == 4
        crop = left(x2,y2,w2,h2,r3,r4,fli,new_w,new_h);               
    elseif class_guess == 5
        crop = expand(x2,y2,w2,h2,r3,r4,fli,bnew_w,bnew_h);
    elseif class_guess == 6
        crop = shrink(x2,y2,w2,h2,r3,r4,fli,snew_w,snew_h);
    elseif class_guess == 8;
        crop = expand(x2,y2,w2,h2,r3,r4,fli,w2*1.4,h2*1.4);    
    end

    new_crop = crop;
    IOU = round(bboxOverlapRatio(new_crop,ground),-1);