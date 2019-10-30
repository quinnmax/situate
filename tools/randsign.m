function out = randsign(varargin)

    s = rand(varargin{:});
    out = 2*(s>.5)-1;
    
end
