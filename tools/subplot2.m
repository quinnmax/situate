
function h = subplot2( rows, cols, rp0, cp0, rpf, cpf )

    % h = subplot2( rows, cols, rp, cp )
    %   or
    % h = subplot2( rows, cols, rp0, cp0, rpf, cpf );
    

    if nargin < 6
        rpf = rp0;
        cpf = cp0;
    end

    temp = subplot( rows, cols, [ spi(cols,rp0,cp0) spi(cols,rpf,cpf) ] );
    
    if nargout > 0
        h = temp;
    end
    
end

function ind = spi(cols,rp,cp)

    ind = (rp-1)*cols + cp;
    
end