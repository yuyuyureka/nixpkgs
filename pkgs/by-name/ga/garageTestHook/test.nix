{
  garage,
  garageTestHook,
  stdenv,
  awscli,
}:

stdenv.mkDerivation {
  name = "garage-test-hook-test";
  nativeCheckInputs = [ garageTestHook garage awscli ];
  dontUnpack = true;
  doCheck = true;
  passAsFile = [ "testFile" ];
  testFile = ''
    It worked!
  '';
  garageTestSetupPost = ''
    TEST_POST_HOOK_RAN=1
  '';
  checkPhase = ''
    runHook preCheck

    aws s3 --endpoint-url "$AWS_S3_ENDPOINT_URL" ls | grep testbucket
    aws s3 --endpoint-url "$AWS_S3_ENDPOINT_URL" ls s3://testbucket | (! grep testFile)
    aws s3 --endpoint-url "$AWS_S3_ENDPOINT_URL" cp $testFilePath s3://testbucket/testFile
    aws s3 --endpoint-url "$AWS_S3_ENDPOINT_URL" ls s3://testbucket | grep testFile
    aws s3 --endpoint-url "$AWS_S3_ENDPOINT_URL" cp s3://testbucket/testFile ./testFile
    diff "$testFilePath" "testFile"
    TEST_RAN=1

    runHook postCheck
  '';
  installPhase = ''
    [[ $TEST_RAN == 1 && $TEST_POST_HOOK_RAN == 1 ]]
    touch $out
  '';
}
