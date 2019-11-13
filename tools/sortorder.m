function order_out = sortorder( data_in, varargin )

    % order_out = sortorder( data_in, varargin );
    % just [~,order_out] = sort( data_in, varargin{:} );
    
    if ~isempty(varargin)
        [~,order_out] = sort( data_in, varargin{:} );
    else
        [~,order_out] = sort( data_in );
    end
    
end