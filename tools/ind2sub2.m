function inds_out = ind2sub2(siz,ndx)

    % inds_out = ind2sub2(siz,ndx);
    % like ind2sub, but doesn't need you to specify the number of outputs.
    % the size of inds_out is based on the number of dimensions in siz

    siz = double(siz);
    lensiz = length(siz);

    inds_out = zeros(lensiz,length(ndx));

    k = cumprod(siz);
    for i = lensiz:-1:3,
        vi = rem(ndx-1, k(i-1)) + 1;
        vj = (ndx - vi)/k(i-1) + 1;
        inds_out(i,:) = double(vj);
        ndx = vi;
    end

    vi = rem(ndx-1, siz(1)) + 1;
    inds_out(2,:) = double((ndx - vi)/siz(1) + 1);
    inds_out(1,:) = double(vi);
    
    inds_out = inds_out';




