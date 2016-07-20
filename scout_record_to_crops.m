

function [] = scout_record_to_crops( scout_record_fname )

   if ~exist('scout_record_fname','var') || isempty( scout_record_fname)
        scout_record_fname = 'scout_records_modified.mat';
    end

    load(scout_record_fname);
    resize_target_px = 250000;
    
    if ~exist('situate_crops','dir'), mkdir('situate_crops'); end
    
    for imi = 1:length(scout_records)
        
        for ci = 1:size( scout_records(imi).box_r0rfc0cf,1 )

            im = imread(scout_records(imi).im_fname);
            im_r = imresize_px( im, resize_target_px );
            
            r0 = scout_records(imi).box_r0rfc0cf(ci,1);
            rf = scout_records(imi).box_r0rfc0cf(ci,2);
            c0 = scout_records(imi).box_r0rfc0cf(ci,3);
            cf = scout_records(imi).box_r0rfc0cf(ci,4);

            r0 = size(im,1) * r0 / size(im_r,1);
            rf = size(im,1) * rf / size(im_r,1);
            c0 = size(im,2) * c0 / size(im_r,2);
            cf = size(im,2) * cf / size(im_r,2);
            
            r0 = round(r0);
            rf = round(rf);
            c0 = round(c0);
            cf = round(cf);
            
            r0 = max( r0, 1 );
            c0 = max( c0, 1 );
            rf = min( rf, size(im,1) );
            cf = min( cf, size(im,2) );
            
            if ~any([ r0==0,rf==0,c0==0,cf==0 ])

                cur_crop = im( r0:rf, c0:cf, : );

                im_fname_split = split(scout_records(imi).im_fname,{'/','.'});
                iou_dog = scout_records(imi).iou_dog(ci);
                iou_person = scout_records(imi).iou_person(ci);
                iou_leash = scout_records(imi).iou_leash(ci);
                crop_fname = [ 'situate_crops/' im_fname_split{end-1} '_crop_' num2str(ci,'%.4d') '_' scout_records(imi).interest{ci} sprintf('_%0.2f_%0.2f_%0.2f.jpg',[iou_dog iou_person iou_leash])];

                imwrite(cur_crop, crop_fname);

            % else 
            %   We must have allocated for more scouting, 
            %   but the run finished after making all of the detections, 
            %   so it stopped and we don't have any more crops to pull.
            end

        end
        
    end
    
end






