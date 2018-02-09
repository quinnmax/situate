function support = custom( internal, external, varargin )
                
    a = varargin{1};
    b = varargin{2};
    support = a * internal + b * external;
    
end