function y = FarrowInterpolator(x, mu)
    % x: Input samples (vector)
    % mu: Fractional delay (scalar, 0 <= mu < 1)
    % y: Interpolated output

    % Coefficients for cubic interpolation
    h0 = -1/6 * (mu - 1) * mu * (mu + 1);
    h1 =  1/2 * (mu - 1) * (mu + 1) * (mu + 2);
    h2 = -1/2 * mu * (mu + 1) * (mu + 2);
    h3 =  1/6 * mu * (mu - 1) * (mu + 2);

    % Perform interpolation
    y = h0 * x(1) + h1 * x(2) + h2 * x(3) + h3 * x(4);
end