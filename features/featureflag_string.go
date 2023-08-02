// Code generated by "stringer -type=FeatureFlag"; DO NOT EDIT.

package features

import "strconv"

func _() {
	// An "invalid array index" compiler error signifies that the constant values have changed.
	// Re-run the stringer command to generate them again.
	var x [1]struct{}
	_ = x[unused-0]
	_ = x[StoreRevokerInfo-1]
	_ = x[ROCSPStage6-2]
	_ = x[ROCSPStage7-3]
	_ = x[StoreLintingCertificateInsteadOfPrecertificate-4]
	_ = x[CAAValidationMethods-5]
	_ = x[CAAAccountURI-6]
	_ = x[EnforceMultiVA-7]
	_ = x[MultiVAFullResults-8]
	_ = x[ECDSAForAll-9]
	_ = x[ServeRenewalInfo-10]
	_ = x[AllowUnrecognizedFeatures-11]
	_ = x[ExpirationMailerUsesJoin-12]
	_ = x[CertCheckerChecksValidations-13]
	_ = x[CertCheckerRequiresValidations-14]
	_ = x[CertCheckerRequiresCorrespondence-15]
	_ = x[AsyncFinalize-16]
	_ = x[RequireCommonName-17]
	_ = x[LeaseCRLShards-18]
}

const _FeatureFlag_name = "unusedStoreRevokerInfoROCSPStage6ROCSPStage7StoreLintingCertificateInsteadOfPrecertificateCAAValidationMethodsCAAAccountURIEnforceMultiVAMultiVAFullResultsECDSAForAllServeRenewalInfoAllowUnrecognizedFeaturesExpirationMailerUsesJoinCertCheckerChecksValidationsCertCheckerRequiresValidationsCertCheckerRequiresCorrespondenceAsyncFinalizeRequireCommonNameLeaseCRLShards"

var _FeatureFlag_index = [...]uint16{0, 6, 22, 33, 44, 90, 110, 123, 137, 155, 166, 182, 207, 231, 259, 289, 322, 335, 352, 366}

func (i FeatureFlag) String() string {
	if i < 0 || i >= FeatureFlag(len(_FeatureFlag_index)-1) {
		return "FeatureFlag(" + strconv.FormatInt(int64(i), 10) + ")"
	}
	return _FeatureFlag_name[_FeatureFlag_index[i]:_FeatureFlag_index[i+1]]
}
