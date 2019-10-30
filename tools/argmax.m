function ai = argmax( x, varargin )

    if ~isempty(varargin)
        [~,ai] = max(x, varargin{:} );
    else
        [~,ai] = max(x);
    end