
% taking a look at geometric mean as a measure of total situation support

for num_objects = [1,2,3,5]

    workspaces_to_try = [];
    n = 5;
    workspaces_to_try = vertcat( workspaces_to_try, [linspace(1,0,n)'  1  * ones(n,num_objects-1)] );
    workspaces_to_try = vertcat( workspaces_to_try, [linspace(1,0,n)' .75 * ones(n,num_objects-1)] );
    workspaces_to_try = vertcat( workspaces_to_try, [linspace(1,0,n)' .5  * ones(n,num_objects-1)] );
    workspaces_to_try = vertcat( workspaces_to_try, [linspace(1,0,n)' .25 * ones(n,num_objects-1)] );

    geometric_mean = @(x) prod(x).^(1/length(x));

    for i = 1:length(workspaces_to_try)

        cur_workspace = workspaces_to_try(i,:);
        workspace_support = geometric_mean( cur_workspace );
        fprintf([repmat('%3.2f ',1,num_objects) ': %3.2f \n'], cur_workspace, workspace_support );

    end


    workspaces_to_try = [];
    n = 5;
    workspaces_to_try = vertcat( workspaces_to_try, [linspace(1,0,n)'  1  * ones(n,num_objects-1)] );
    workspaces_to_try = vertcat( workspaces_to_try, [linspace(1,0,n)' .75 * ones(n,num_objects-1)] );
    workspaces_to_try = vertcat( workspaces_to_try, [linspace(1,0,n)' .5  * ones(n,num_objects-1)] );
    workspaces_to_try = vertcat( workspaces_to_try, [linspace(1,0,n)' .25 * ones(n,num_objects-1)] );

    geometric_mean = @(x) prod(x).^(1/length(x));

    for i = 1:length(workspaces_to_try)

        cur_workspace = workspaces_to_try(i,:);
        workspace_support = geometric_mean( cur_workspace );
        fprintf([repmat('%3.2f ',1,num_objects) ': %3.2f \n'], cur_workspace, workspace_support );


    end

end
