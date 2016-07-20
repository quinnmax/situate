function box = format_box( box, im )
    box(3:4) = box(3:4) - box(1:2) + 1;
    [im_width, im_height] = size(im);
    box(1:2) = box(1:2) - [im_width, im_height]/2;
    box(1:4) = box(1:4) / sqrt(im_width * im_height);
end
