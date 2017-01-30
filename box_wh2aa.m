
function [aspect,area] = box_aa2wh(w,h)

    % [aspect,area] = box_aa2wh(w,h)
    %
    % given the w,h, 
    % get the aspect ratio and area (in total pixels) of a box
    
    aspect = w/h;
    area = w*h;
     
end
