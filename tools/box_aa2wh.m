
function [w,h] = box_aa2wh(aspect,area)

    % [w,h] = box_aa2wh(aspect,area);
    %
    % given the aspect ratio and area (in total pixels) of a box, the width and height of the
    % box are generated. 
    
    h = sqrt( area ./ aspect );
    w = area ./ h;
     
end
