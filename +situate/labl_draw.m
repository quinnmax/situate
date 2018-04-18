function [] = labl_draw( lb_fname, varargin )
% labl_draw( lb_fname );
% labl_draw( lb_fname, situation_struct );


    if ~isempty(varargin)
        situation_struct = varargin{1};
    else
        situation_struct = [];
    end

    lb_struct = situate.labl_load( lb_fname, situation_struct  );

    im_fname = [fileparts_mq(lb_fname,'path/name') '.jpg'];
    imshow(im_fname);
    hold on;
    for bi = 1:size(lb_struct.boxes_r0rfc0cf,1)
        draw_box( lb_struct.boxes_r0rfc0cf(bi,:), 'r0rfc0cf', 'LineWidth',5);
        
        x = lb_struct.boxes_r0rfc0cf(bi,3);
        y = lb_struct.boxes_r0rfc0cf(bi,1);
        
        if isempty(situation_struct)
           text( x,y, lb_struct.labels_raw{bi},'FontSize', 24, 'Color', [0 0 0] );
            text( x+1,y+1, lb_struct.labels_raw{bi},'FontSize', 24, 'Color', [1 1 1] );
        else
            text( x,y, lb_struct.labels_adjusted{bi},'FontSize', 24, 'Color', [0 0 0] );
            text( x+1,y+1, lb_struct.labels_adjusted{bi},'FontSize', 24, 'Color', [1 1 1] );
        end
            
    end
    
end