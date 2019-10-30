function support = dissertation_fit(bx,varargin)

% support = dissertation_fit(bx,learned_models,object_index);
   
    learned_models = varargin{1};
    oi = varargin{2};

    p_x  = learned_models.situation_model.p_x(oi);
    p_bx = learned_models.situation_model.bx(oi);

    psi = @(t) log( p_bx ) + log( 1 - p_x ) - log( bx ) - log( p_x );
    p_x_bxyby_func = @(t) 1 ./ ( 1 + exp( psi(t) ) );
    p_x_bxyby = p_x_bxyby_func( bx );
    
    support = p_x_bxyby;
    
end
