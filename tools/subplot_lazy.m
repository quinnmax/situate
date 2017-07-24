

function subplot_lazy(k,ki)

    % subplot_lazy(k,ki);
    %
    % rows = floor(sqrt(k));
    % cols = ceil(k/floor(sqrt(k)));

    rows = floor(sqrt(k));
    cols = ceil(k/floor(sqrt(k)));
    subplot( rows, cols, ki );
    
end