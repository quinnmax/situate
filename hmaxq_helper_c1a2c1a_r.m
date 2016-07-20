function c1a_r = hmaxq_helper_c1a2c1a_r( c1a )

    % c1a_r = hmaxq_helper_c1a2c1a_r( c1a );
    %
    % takes a c1a cell array (which is divided up by scales)
    % and reshapes each cell so they can be stacked up into 

    nr = max( cellfun( @(x) size(x,1), c1a ) );
    nc = max( cellfun( @(x) size(x,2), c1a ) );
    nf = size(c1a{1},3);
    
    total_scales = length( c1a );
    total_layers = nf  * total_scales;
    c1a_r = zeros( nr, nc, total_layers );
    
    ci = 1;
    for si = 1:total_scales
        l0 = ci;
        lf = ci + nf - 1;
        c1a_r(:,:,l0:lf) = imresize( c1a{si}, [nr nc], 'nearest' );
        ci = lf + 1;
    end
    
end
    
    