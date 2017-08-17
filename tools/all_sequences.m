function output = all_sequences( input )
    % output = all_sequences( input );
    %
    % input can be matrix, cell, string
    

    if ~exist('input','var'), input = [1 2 3]; end
    if length(input) == 1, output = input; return; end
    
    output = input;
    output(:) = [];
    for i = 1:length(input)
        temp1 = all_sequences( setsub(input,input(i) ) );
        temp2 = [ repmat(input(i),size(temp1,1),1) temp1 ];
        output(end+1:end+size(temp2,1),:) = temp2;
    end
    
end
        
    




