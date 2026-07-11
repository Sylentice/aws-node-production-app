#!/usr/bin/env bash
set -euo pipefail

env_file="${ENV_FILE:-.env}"
example_file="${ENV_EXAMPLE_FILE:-.env.example}"
required_vars="${REQUIRED_ENV_VARS:-POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB DATABASE_URL JWT_SECRET}"
secret_vars="${SECRET_ENV_VARS:-POSTGRES_PASSWORD DATABASE_URL JWT_SECRET}"
check_failed=false

get_env_value() {
  file="$1"
  var_name="$2"

  grep -E "^[[:space:]]*$var_name=" "$file" 2>/dev/null \
    | tail -n 1 \
    | sed -E "s/^[[:space:]]*$var_name=//"
}

echo
echo "============================================================"
echo "Environment Example Check"
echo "============================================================"
echo "Example file: $example_file"
echo "Real env file: $env_file"
echo "Required variables: $required_vars"
echo "Secret-like variables checked for placeholder safety: $secret_vars"
echo
echo "Secret values will not be printed."

if [ ! -f "$example_file" ]; then
  echo "$example_file does not exist"
  exit 1
fi

echo
echo "Checking Git ignore behavior..."

if git check-ignore -q "$example_file"; then
  echo "$example_file is ignored by Git"
  check_failed=true
else
  echo "$example_file is not ignored by Git"
fi

if [ -f "$env_file" ]; then
  if git check-ignore -q "$env_file"; then
    echo "$env_file is ignored by Git"
  else
    echo "$env_file is not ignored by Git"
    check_failed=true
  fi

  if git ls-files --error-unmatch "$env_file" >/dev/null 2>&1; then
    echo "$env_file is tracked by Git"
    check_failed=true
  else
    echo "$env_file is not tracked by Git"
  fi
else
  echo "$env_file does not exist locally; skipping real env comparisons"
fi

echo
echo "Checking required variables in $example_file..."

for var_name in $required_vars; do
  if grep -Eq "^[[:space:]]*$var_name=" "$example_file"; then
    example_value=$(get_env_value "$example_file" "$var_name")

    if [ -n "$example_value" ]; then
      echo "$var_name exists in $example_file"
    else
      echo "$var_name exists in $example_file but is empty"
      check_failed=true
    fi
  else
    echo "$var_name is missing from $example_file"
    check_failed=true
  fi
done

echo
echo "Checking secret-like placeholders do not match real values..."

for var_name in $secret_vars; do
  if [ -f "$env_file" ] \
    && grep -Eq "^[[:space:]]*$var_name=" "$env_file" \
    && grep -Eq "^[[:space:]]*$var_name=" "$example_file"; then

    real_value=$(get_env_value "$env_file" "$var_name")
    example_value=$(get_env_value "$example_file" "$var_name")

    if [ -n "$real_value" ] && [ "$example_value" = "$real_value" ]; then
      echo "$var_name in $example_file matches the real value in $env_file"
      check_failed=true
    else
      echo "$var_name uses a safe placeholder value"
    fi
  fi
done

echo
echo "Checking for obvious placeholder language..."

if grep -Eq "change_me|example|placeholder" "$example_file"; then
  echo "$example_file contains placeholder language"
else
  echo "$example_file does not appear to contain placeholder language"
  check_failed=true
fi

if [ "$check_failed" = "true" ]; then
  echo
  echo "Environment example check failed"
  exit 1
fi

echo
echo "Environment example check passed"
