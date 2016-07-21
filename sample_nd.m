function [s,s_inds] = sample_nd( pdf, n, domains )
    % [s,s_inds]= sample_nd( pdf, n, domains );
    %
    % pdf can be any number of dimensions
    % domains is a cell array, each containing values associated with the
    % index positions of dimensions in pdf. 
    % if pdf is 5x3x7, then domains should be {[1x5],[1x3],[1x7]}
    % n is the number of samples to draw
    
    
    cdf_linear = cumsum(pdf(:));
    sum_pdf = sum(pdf(:));
    epsilon = .00000001;
    if sum_pdf < 1 || sum_pdf > 1+epsilon
        cdf_linear = cdf_linear/sum_pdf;
    end
    dims = ndims(pdf);
    if length(pdf) == numel(pdf), dims = 1; end
    
    r = rand(1,n);
    s_linear_inds = zeros(1,n);
    for ni = 1:n
        s_linear_inds(ni) = find( cdf_linear > r(ni), 1, 'first' );
    end
    
    if dims == 1
        s_inds = s_linear_inds;
        if ~exist('domains','var') || isempty(domains)
            s = s_inds;
        else
            s = domains{1}(s_inds);
        end
    else % more than 1 dim
        s_inds = ind2sub2( size(pdf), s_linear_inds );
        if ~exist('domains','var') || isempty(domains)
            s = s_inds;
        else
            s = zeros(size(s_inds));
            for i = 1 : dims
                s(:,i) = domains{i}(s_inds(:,i));
            end
        end
    end
    
end
    


function inds_out = ind2sub2(siz,ndx)

    % inds_out = ind2sub2(siz,ndx);
    % like ind2sub, but doesn't need you to specify the number of outputs.
    % the size of inds_out is based on the number of dimensions in siz

    siz = double(siz);
    lensiz = length(siz);
    if min(siz) == 1, lensiz = 1; end

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

end
    
    
    
    
    
    
    
    
    
    
    