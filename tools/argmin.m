function ai = argmin( x, varargin )

    if ~isempty(varargin)
        [~,ai] = min(x, varargin{:} );
    else
        [~,ai] = min(x);
    end