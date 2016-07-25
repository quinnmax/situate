% mvn_marginalize_and_condition_ts

    % given a joint distribution, we want to get a conditional distribution for
    % some specified dimensions given some known data

    % first, specify what we want and what we have

    want_data_inds = [1 1 0 0]; % we want a distribution for the first dimensions
    have_data_inds = [0 0 0 0]; % we have data for the third dimensions
    known_data     = [nan nan .5 .75];
    
    % load up (or make) the joint distribution that we got from training data

    joint_mu    = rand(1,4);
    joint_Sigma = rand(4,4);
    joint_Sigma = joint_Sigma + joint_Sigma'; % fake a symmetrical matrix
    
    [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( joint_mu, joint_Sigma, want_data_inds, have_data_inds, known_data );
