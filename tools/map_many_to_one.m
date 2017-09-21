
function output = map_many_to_one( input, domains, codomains )
% output = map_many_to_one( input, domains, codomains );
% if input is in domains{i}, then output = codomains{i}
%
% if input is in multiple domains, then the the output returned will be the codomain associated with
% the first domain to contain the input.

    % input = 'x';
    % domains = { {'a','b','c'}, {'x','y','z'} };
    % codomains = {'early';'late'};

    % input = 'g';
    % domains = { {'a','b','c'}, {'x','y','z'} };
    % codomains = {'early';'late'};

    if iscell( input )
        output = cell(size(input));
        for i = 1:numel(input)
            output{i} = map_many_to_one( input{i}, domains, codomains );
        end
        return
    end

    ind = find( cellfun( @(x) ismember(input,x), domains ), 1, 'first');
    if ~isempty(ind)
        output = codomains{ find( cellfun( @(x) ismember(input,x), domains ), 1, 'first') };
    else
        output = [];
    end
      
end






