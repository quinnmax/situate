

function intersect_area = intersect_mq( boxA, boxB )

    % intersect_area = intersect_mq( boxA, boxB );
    %
    % box format [r0 rf c0 cf];

    r0a = boxA(1);
    rfa = boxA(2);
    c0a = boxA(3);
    cfa = boxA(4);

    r0b = boxB(1);
    rfb = boxB(2);
    c0b = boxB(3);
    cfb = boxB(4);

    intersect_r = min(rfa,rfb) - max(r0a,r0b);
    intersect_c = min(cfa,cfb) - max(c0a,c0b);
    if intersect_r > 0 && intersect_c > 0
        intersect_area = intersect_r * intersect_c;
    else
        intersect_area = 0;
    end

end
